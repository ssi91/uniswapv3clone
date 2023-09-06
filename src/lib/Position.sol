// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library Position {
    struct Info {
        uint128 liquidity;
    }

    function update(Info storage self, uint128 liquidityDelta) internal {
        self.liquidity += liquidityDelta;
    }

    function get(
        mapping(bytes32 => Info) storage self,
        address owner,
        int24 lowerTick,
        int24 upperTick
    ) internal view returns (Info storage position) {
        position = self[keccak256(abi.encodePacked(owner, lowerTick, upperTick))];
    }
}
