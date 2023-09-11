// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./UniswapV3Pool.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";

contract UniswapV3Manager is IUniswapV3SwapCallback, IUniswapV3MintCallback {
    constructor(){
    }

    function mint(
        address poolAddress,
        int24 lowerTick,
        int24 upperTick,
        uint128 liquidity,
        bytes calldata data
    ) external {
        UniswapV3Pool(poolAddress).mint(
            msg.sender,
            lowerTick,
            upperTick,
            liquidity,
            data
        );
    }

    function swap(address poolAddress, bytes calldata data) external {
        UniswapV3Pool(poolAddress).swap(msg.sender, data);
    }

    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data) external {
        UniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniswapV3Pool.CallbackData)
        );
        if (amount0 > 0) {
            IERC20(extra.token0).transferFrom(extra.payer, msg.sender, uint256(amount0));
        }
        if (amount1 > 0) {
            IERC20(extra.token1).transferFrom(extra.payer, msg.sender, uint256(amount1));
        }
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
        UniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniswapV3Pool.CallbackData)
        );

        IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
        IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
    }

}
