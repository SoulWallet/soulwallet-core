// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Authority} from "./Authority.sol";
import {IFallbackManager} from "../interface/IFallbackManager.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";

abstract contract FallbackManager is IFallbackManager, Authority {
    receive() external payable virtual {}

    /**
     * @dev Sets the address of the fallback handler contract
     * @param fallbackContract The address of the new fallback handler contract
     */
    function _setFallbackHandler(address fallbackContract) internal virtual {
        AccountStorage.layout().defaultFallbackContract = fallbackContract;
    }

    /**
     * @notice Fallback function that forwards all requests to the fallback handler contract
     * @dev The request is forwarded using a STATICCALL
     * It ensures that the state of the contract doesn't change even if the fallback function has state-changing operations
     */
    fallback() external payable virtual {
        address fallbackContract = AccountStorage.layout().defaultFallbackContract;
        assembly {
            /* not memory-safe */
            calldatacopy(0, 0, calldatasize())
            let result := staticcall(not(0), fallbackContract, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /**
     * @notice Sets the address of the fallback handler and emits the FallbackChanged event
     * @param fallbackContract The address of the new fallback handler
     */
    function setFallbackHandler(address fallbackContract) external virtual override {
        fallbackManagementAccess();
        _setFallbackHandler(fallbackContract);
        emit FallbackChanged(fallbackContract);
    }
}
