// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUpgradeManager} from "../interface/IUpgradeManager.sol";
import {Authority} from "./Authority.sol";

abstract contract UpgradeManager is IUpgradeManager, Authority {
    error INVALID_LOGIC_ADDRESS();
    error SAME_LOGIC_ADDRESS();

    /**
     * @notice Storage slot with the address of the current implementation
     * @dev This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
     */
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function upgradeTo(address newImplementation) external virtual override onlySelfOrModule {
        bool isContract;
        assembly ("memory-safe") {
            isContract := gt(extcodesize(newImplementation), 0)
        }
        if (!isContract) {
            revert INVALID_LOGIC_ADDRESS();
        }
        address oldImplementation;
        assembly ("memory-safe") {
            oldImplementation := and(sload(_IMPLEMENTATION_SLOT), 0xffffffffffffffffffffffffffffffffffffffff)
        }
        if (oldImplementation == newImplementation) {
            revert SAME_LOGIC_ADDRESS();
        }
        assembly ("memory-safe") {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }
    }
}
