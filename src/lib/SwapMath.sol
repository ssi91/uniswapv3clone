// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Math.sol";

library SwapMath {
    function computeSwapStep(
        uint160 sqrtPriceCurrentX96,
        uint160 sqrtPriceTargetX96,
        uint128 liquidity,
        uint256 amountRemaining
    ) internal pure returns (
        uint160 sqrtPriceNextX96,
        uint256 amountIn,
        uint256 amountOut
    ) {
        bool zeroToOne = sqrtPriceCurrentX96 >= sqrtPriceTargetX96;

        amountIn = zeroToOne ? Math.calcAmount0Delta(
            sqrtPriceCurrentX96,
            sqrtPriceNextX96,
            liquidity
        ) : Math.calcAmount1Delta(
            sqrtPriceCurrentX96,
            sqrtPriceNextX96,
            liquidity
        );

        if (amountRemaining >= amountIn)
            sqrtPriceNextX96 = sqrtPriceTargetX96;
        else
            sqrtPriceNextX96 = Math.getNextSqrtPriceFromInput(
                sqrtPriceCurrentX96,
                liquidity,
                amountRemaining,
                zeroToOne
            );

        amountIn = Math.calcAmount0Delta(
            sqrtPriceCurrentX96,
            sqrtPriceNextX96,
            liquidity
        );
        amountOut = Math.calcAmount1Delta(
            sqrtPriceCurrentX96,
            sqrtPriceNextX96,
            liquidity
        );

        if (!zeroToOne) {
            (amountIn, amountOut) = (amountOut, amountIn);
        }
    }
}
