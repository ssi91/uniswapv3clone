// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroToOne, // true if token0 traded in for token1
        uint256 amountSpecified, // amount of tokens user wants to sell
        bytes calldata data
    ) public returns (int256 amount0, int256 amount1);
}
