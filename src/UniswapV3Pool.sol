// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./lib/Math.sol";
import "./lib/Tick.sol";
import "./lib/TickMath.sol";
import "./lib/SwapMath.sol";
import "./lib/Position.sol";
import "./lib/LiquidityMath.sol";
import "./lib/TickBitmap.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";

contract UniswapV3Pool {
    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    struct StateSwap {
        uint256 amountSpecifiedRemaining;
        uint256 amountCalculated;
        uint160 sqrtPriceX96;
        int24 tick;
    }

    struct StepState {
        uint160 sqrtPriceStartX96;
        int24 nextTick;
        uint160 sqrtPriceNextX96;
        uint256 amountIn;
        uint256 amountOut;
    }

    using TickBitmap for mapping(int16 => uint256);
    mapping(int16 => uint256) public tickBitmap;

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
        uint128 amount,
        bytes calldata callback
    ) external returns (uint256 amount0, uint256 amount1) {
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) {
            revert("Invalid tick range");
        }
        if (amount == 0) {
            revert("Zero liquidity");
        }

        bool flippedLower = ticks.update(lowerTick, amount);
        bool flippedUpper = ticks.update(upperTick, amount);

        if (flippedLower) {
            tickBitmap.flipTick(lowerTick, 1);
        }
        if (flippedUpper) {
            tickBitmap.flipTick(upperTick, 1);
        }

        Position.Info storage position = positions.get(owner, lowerTick, upperTick);
        position.update(amount);

        Slot0 memory slot0_ = slot0;

        if (slot0_.tick < lowerTick) {
            amount0 = Math.calcAmount0Delta(
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                amount
            );
        } else if (slot0_.tick < upperTick) {
            amount0 = Math.calcAmount0Delta(
                slot0.sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(upperTick),
                amount
            );
            amount1 = Math.calcAmount1Delta(
                slot0.sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(lowerTick),
                amount
            );

            // `liquidity` variable tracks liquidity that’s available immediately
            liquidity = LiquidityMath.addLiquidity(liquidity, amount);
        } else {
            amount1 = Math.calcAmount1Delta(
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(lowerTick),
                amount
            );
        }

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) {
            balance0Before = balance0();
        }
        if (amount1 > 0) {
            balance1Before = balance1();
        }
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, callback);

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

    function swap(
        address recipient,
        bool zeroToOne, // true if token0 traded in for token1
        uint256 amountSpecified, // amount of tokens user wants to sell
        bytes calldata data
    ) public returns (int256 amount0, int256 amount1) {
        Slot0 memory slot0_ = slot0;

        StateSwap memory state = StateSwap({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0_.sqrtPriceX96,
            tick: slot0_.tick
        });

        while (state.amountSpecifiedRemaining > 0) {
            StepState memory step;
            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.nextTick,) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                1,
                zeroToOne
            );

            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);

            (state.sqrtPriceX96, step.amountIn, step.amountOut) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                step.sqrtPriceNextX96,
                liquidity,
                state.amountSpecifiedRemaining
            );

            state.amountSpecifiedRemaining -= step.amountIn;
            state.amountCalculated += step.amountOut;
            state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
        }

        // next, update the current tick and price
        if (slot0.tick != state.tick)
            (slot0.tick, slot0.sqrtPriceX96) = (state.tick, state.sqrtPriceX96);

        (amount0, amount1) = zeroToOne ? (
            int256(amountSpecified - state.amountSpecifiedRemaining),
            - int256(state.amountCalculated)
        ) : (
            - int256(state.amountCalculated),
            int256(amountSpecified - state.amountSpecifiedRemaining)
        );

        // send tokens to recipient
        if (zeroToOne) {
            IERC20(token1).transfer(recipient, uint256(- amount1));

            uint256 balance0Before = balance0();

            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);

            if (balance0Before + uint256(amount0) != balance0()) {
                revert("Insufficient balance");
            }
        } else {
            IERC20(token0).transfer(recipient, uint256(- amount0));

            uint256 balance1Before = balance1();

            // sender sends the token1 within this callback
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
            if (balance1Before + uint256(amount1) != balance1()) {
                revert("Insufficient balance");
            }
        }
        emit Swap(msg.sender, recipient, amount0, amount1, slot0.sqrtPriceX96, liquidity, slot0.tick);
    }
}
