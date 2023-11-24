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

    bytes4 private constant INTERFACE_ID_HOOK = type(IHook).interfaceId;

    function _hookMapping() internal view returns (mapping(address => address) storage hooks) {
        hooks = AccountStorage.layout().hooks;
    }

    function _installHook(address hook) internal virtual {
        try IHook(hook).supportsInterface(INTERFACE_ID_HOOK) returns (bool supported) {
            if (supported == false) {
                revert INVALID_HOOK();
            } else {
                _hookMapping().add(hook);
            }
        } catch {
            revert INVALID_HOOK();
        }
    }

    function _uninstallHook(address hook) internal virtual {
        _hookMapping().remove(hook);
    }

    function _cleanHook() internal virtual {
        _hookMapping().clear();
    }

    function installHook(address hook) external virtual override onlySelfOrModule {
        _installHook(hook);
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
