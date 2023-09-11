// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./lib/Tick.sol";
import "./lib/Position.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";

contract UniswapV3Pool {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    int24 internal constant MIN_TICK = - 887272;
    int24 internal constant MAX_TICK = - MIN_TICK;

    address public immutable token0;
    address public immutable token1;

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
    }

    Slot0 public slot0;

    uint128 public liquidity;

    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;

    event Mint(
        address indexed sender,
        address indexed owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    constructor(
        address token0_,
        address token1_,
        uint160 sqrtPriceX96,
        int24 tick
    ){
        token0 = token0_;
        token1 = token1_;
        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick});
    }

    function mint(
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1) {
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) {
            revert("Invalid tick range");
        }
        if (amount == 0) {
            revert("Zero liquidity");
        }

        ticks.update(lowerTick, amount);
        ticks.update(upperTick, amount);

        Position.Info storage position = positions.get(owner, lowerTick, upperTick);
        position.update(amount);

        // TODO: replace with actual calculations
        amount0 = 0.998976618347425280 ether;
        amount1 = 5000 ether;

        liquidity += amount;

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) {
            balance0Before = balance0();
        }
        if (amount1 > 0) {
            balance1Before = balance1();
        }
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1);

        if (amount0 > 0 && balance0Before + amount0 > balance0()) {
            revert("Insufficient input amount");
        }
        if (amount1 > 0 && balance1Before + amount1 > balance1()) {
            revert("Insufficient input amount");
        }

        emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
    }

    function balance0() internal returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }

    function swap(address recipient) public returns (int256 amount0, int256 amount1) {
        // tick and price values are hardcoded
        // it must be calculated instead
        // as well as values of amounts
        int24 nextTick = 85154;
        uint160 nextPrice = 5604469350942327889444743441197;

        amount0 = - 0.008396714242162444 ether;
        amount1 = 42 ether;

        // next, update the current tick and price
        (slot0.tick, slot0.sqrtPriceX96) = (nextTick, nextPrice);

        // send tokens to recipient
        IERC20(token0).transfer(recipient, uint256(- amount0));

        uint256 balance1Before = balance1();

        // sender sends the token1 within this callback
        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1);
        if (balance1Before + uint256(amount1) != balance1()) {
            revert("Insufficient balance");
        }

        emit Swap(msg.sender, recipient, amount0, amount1, slot0.sqrtPriceX96, liquidity, slot0.tick);
    }
}
