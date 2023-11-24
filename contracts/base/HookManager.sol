// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Authority} from "./Authority.sol";
import {IHookManager} from "../interface/IHookManager.sol";
import {IHook} from "../interface/IHook.sol";
import {IAccount, UserOperation} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";
import {AddressLinkedList} from "../utils/AddressLinkedList.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";

abstract contract HookManager is Authority, IHookManager, IERC1271 {
    using AddressLinkedList for mapping(address => address);

    error INVALID_HOOK();
    error INVALID_HOOK_TYPE();
    error HOOK_NOT_EXISTS();

    bytes4 private constant INTERFACE_ID_HOOK = type(IHook).interfaceId;
    uint8 private constant PRE_IS_VALID_SIGNATURE_HOOK = 1 << 0;
    uint8 private constant PRE_USER_OP_VALIDATION_HOOK = 1 << 1;

    function _installHook(address hook, uint8 capabilityFlags) internal virtual {
        try IHook(hook).supportsInterface(INTERFACE_ID_HOOK) returns (bool supported) {
            if (supported == false) {
                revert INVALID_HOOK();
            } else {
                if (capabilityFlags & (PRE_IS_VALID_SIGNATURE_HOOK | PRE_IS_VALID_SIGNATURE_HOOK) == 0) {
                    revert INVALID_HOOK_TYPE();
                }
                if (capabilityFlags & PRE_IS_VALID_SIGNATURE_HOOK == PRE_IS_VALID_SIGNATURE_HOOK) {
                    AccountStorage.layout().preIsValidSignatureHook.add(hook);
                }
                if (capabilityFlags & PRE_USER_OP_VALIDATION_HOOK == PRE_USER_OP_VALIDATION_HOOK) {
                    AccountStorage.layout().preUserOpValidationHook.add(hook);
                }
            }
        } catch {
            revert INVALID_HOOK();
        }
    }

    function _uninstallHook(address hook) internal virtual {
        if (
            AccountStorage.layout().preIsValidSignatureHook.tryRemove(hook)
                || AccountStorage.layout().preUserOpValidationHook.tryRemove(hook)
        ) {
            revert HOOK_NOT_EXISTS();
        }
    }

    function _cleanHook() internal virtual {
        AccountStorage.layout().preIsValidSignatureHook.clear();
        AccountStorage.layout().preUserOpValidationHook.clear();
    }

    function installHook(address hook, uint8 capabilityFlags) external virtual override onlySelfOrModule {
        _installHook(hook, capabilityFlags);
    }

    function uninstallHook(address hook) external virtual override onlySelfOrModule {
        _uninstallHook(hook);
    }

    function listHook() external view virtual override returns (address[] memory hooks) {
        revert("Not implemented");
    }

    function _preIsValidSignatureHook(bytes32 hash, bytes calldata signature) internal view virtual returns (bool) {
        revert("Not implemented");
    }

    function _preUserOpValidationHook(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        internal
        virtual
        returns (bool)
    {
        revert("Not implemented");
    }
}
