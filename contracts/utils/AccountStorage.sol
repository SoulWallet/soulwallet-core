// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AccountStorage
 * @notice A library that defines the storage layout for the SoulWallet account or contract.
 */
library AccountStorage {
    bytes32 internal constant _ACCOUNT_SLOT = keccak256("soulwallet.contracts.AccountStorage");

    struct Layout {
        // ┌───────────────────┐
        // │     base data     │
        mapping(bytes32 => bytes32) owners;
        address defaultFallbackContract;
        // └───────────────────┘

        // ┌───────────────────┐
        // │     base data     │
        mapping(address => address) validators;
        // └───────────────────┘

        // ┌───────────────────┐
        // │       Module      │
        mapping(address => address) modules;
        mapping(address => mapping(bytes4 => bytes4)) moduleSelectors;
        // └───────────────────┘

        // ┌───────────────────┐
        // │       Plugin      │
        mapping(address => address) plugins;
    }

    /**
     * @notice Returns the layout of the storage for the account or contract.
     * @return l The layout of the storage.
     */
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = _ACCOUNT_SLOT;
        assembly ("memory-safe") {
            l.slot := slot
        }
    }
}
