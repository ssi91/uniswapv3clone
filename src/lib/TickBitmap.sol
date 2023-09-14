// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library TickBitmap {
    function position(int24 tick) private pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(tick >> 8); // // 256
        bitPos = uint8(uint24(tick % 256));
    }

    function flipTick(
        mapping(uint16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        require(tick % tickSpacing == 0);
        (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);

        uint256 mask = 1 << bitPos;
        self[wordPos] ^= mask;
    }
}
