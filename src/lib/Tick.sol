// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library Tick {
    struct Info {
        bool initialized;
        uint128 liquidityGross;
        int128 liquidityNet;
    }

    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint128 liquidityDelta,
        bool upper
    ) internal returns (bool flipped) {
        Tick.Info storage tickInfo = self[tick];
        uint128 liquidityBefore = tickInfo.liquidityGross;
        uint128 liquidityAfter = liquidityBefore + liquidityDelta;

        if (liquidityBefore == 0) {
            tickInfo.initialized = true;
        }

        tickInfo.liquidityGross = liquidityAfter;

        tickInfo.liquidityNet = upper ?
            int128(int256(tickInfo.liquidityNet) - liquidityDelta) :
            int128(int256(tickInfo.liquidityNet) + liquidityDelta);

        flipped = (liquidityAfter == 0) != (liquidityBefore == 0);
    }

    function cross(mapping(int24 => Tick.Info) storage self, int24 tick) view internal returns (int128 liquidityDelta) {
        Tick.Info storage tickInfo = self[tick];
        liquidityDelta = tickInfo.liquidityNet;
    }
}
