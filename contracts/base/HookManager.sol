// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Authority} from "./Authority.sol";
import {IHookManager} from "../interface/IHookManager.sol";
import {IHook} from "../interface/IHook.sol";
import {IPluggable} from "../interface/IPluggable.sol";
import {IAccount, UserOperation} from "../interface/IAccount.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";
import {AddressLinkedList} from "../utils/AddressLinkedList.sol";

abstract contract HookManager is Authority, IHookManager {
    using AddressLinkedList for mapping(address => address);

    error INVALID_HOOK();
    error INVALID_HOOK_TYPE();
    error HOOK_NOT_EXISTS();
    error INVALID_HOOK_SIGNATURE();

    event HOOK_UNINSTALL_WITHERROR(address indexed hookAddress);

    bytes4 private constant INTERFACE_ID_HOOK = type(IHook).interfaceId;
    uint8 private constant PRE_IS_VALID_SIGNATURE_HOOK = 1 << 0;
    uint8 private constant PRE_USER_OP_VALIDATION_HOOK = 1 << 1;

    function isInstalledHook(address hook) external view override returns (bool) {
        return AccountStorage.layout().preUserOpValidationHook.isExist(hook)
            || AccountStorage.layout().preIsValidSignatureHook.isExist(hook);
    }

    function _installHook(bytes calldata hookAndData, uint8 capabilityFlags) internal virtual {
        address hookAddress = address(bytes20(hookAndData[:20]));
        try IHook(hookAddress).supportsInterface(INTERFACE_ID_HOOK) returns (bool supported) {
            if (supported == false) {
                revert INVALID_HOOK();
            } else {
                if (capabilityFlags & (PRE_IS_VALID_SIGNATURE_HOOK | PRE_IS_VALID_SIGNATURE_HOOK) == 0) {
                    revert INVALID_HOOK_TYPE();
                }
                if (capabilityFlags & PRE_IS_VALID_SIGNATURE_HOOK == PRE_IS_VALID_SIGNATURE_HOOK) {
                    AccountStorage.layout().preIsValidSignatureHook.add(hookAddress);
                }
                if (capabilityFlags & PRE_USER_OP_VALIDATION_HOOK == PRE_USER_OP_VALIDATION_HOOK) {
                    AccountStorage.layout().preUserOpValidationHook.add(hookAddress);
                }
            }
        } catch {
            revert INVALID_HOOK();
        }

        bytes memory callData = abi.encodeWithSelector(IPluggable.Init.selector, hookAndData[20:]);
        bytes4 invalidHookSelector = INVALID_HOOK.selector;
        assembly ("memory-safe") {
            let result := call(gas(), hookAddress, 0, add(callData, 0x20), mload(callData), 0x00, 0x00)
            if iszero(result) {
                mstore(0x00, invalidHookSelector)
                revert(0x00, 4)
            }
        }
    }

    function _uninstallHook(address hookAddress) internal virtual {
        if (
            AccountStorage.layout().preIsValidSignatureHook.tryRemove(hookAddress)
                || AccountStorage.layout().preUserOpValidationHook.tryRemove(hookAddress)
        ) {
            revert HOOK_NOT_EXISTS();
        }

        (bool success,) =
            hookAddress.call{gas: 100000 /* max to 100k gas */ }(abi.encodeWithSelector(IPluggable.DeInit.selector));
        if (!success) {
            emit HOOK_UNINSTALL_WITHERROR(hookAddress);
        }
    }

    function installHook(bytes calldata hookAndData, uint8 capabilityFlags)
        external
        virtual
        override
        onlySelfOrModule
    {
        _installHook(hookAndData, capabilityFlags);
    }

    function uninstallHook(address hookAddress) external virtual override onlySelfOrModule {
        _uninstallHook(hookAddress);
    }

    function listHook()
        external
        view
        virtual
        override
        returns (address[] memory preIsValidSignatureHooks, address[] memory preUserOpValidationHooks)
    {
        mapping(address => address) storage preIsValidSignatureHook = AccountStorage.layout().preIsValidSignatureHook;
        preIsValidSignatureHooks =
            preIsValidSignatureHook.list(AddressLinkedList.SENTINEL_ADDRESS, preIsValidSignatureHook.size());
        mapping(address => address) storage preUserOpValidationHook = AccountStorage.layout().preUserOpValidationHook;
        preUserOpValidationHooks =
            preUserOpValidationHook.list(AddressLinkedList.SENTINEL_ADDRESS, preUserOpValidationHook.size());
    }

    function _nextHookSignature(bytes calldata hookSignatures, uint256 cursor)
        private
        pure
        returns (address _hookAddr, uint256 _cursorFrom, uint256 _cursorEnd)
    {
        /* 
            +--------------------------------------------------------------------------------+  
            |                            multi-hookSignature                                 |  
            +--------------------------------------------------------------------------------+  
            |     hookSignature     |    hookSignature      |   ...  |    hookSignature      |
            +-----------------------+--------------------------------------------------------+  
            |     dynamic data      |     dynamic data      |   ...  |     dynamic data      |
            +--------------------------------------------------------------------------------+

            +----------------------------------------------------------------------+  
            |                                 hookSignature                        |  
            +----------------------------------------------------------------------+  
            |      Hook address    | hookSignature length  |     hookSignature     |
            +----------------------+-----------------------------------------------+  
            |        20bytes       |     4bytes(uint32)    |         bytes         |
            +----------------------------------------------------------------------+
         */
        uint256 dataLen = hookSignatures.length;

        if (dataLen > cursor) {
            assembly ("memory-safe") {
                let ptr := add(hookSignatures.offset, cursor)
                _hookAddr := shr(0x60, calldataload(ptr))
                if eq(_hookAddr, 0) { revert(0, 0) }
                _cursorFrom := add(cursor, 24) //20+4
                let guardSigLen := shr(0xE0, calldataload(add(ptr, 20)))
                _cursorEnd := add(_cursorFrom, guardSigLen)
            }
        }
    }

    function _preIsValidSignatureHook(bytes32 hash, bytes calldata hookSignatures)
        internal
        view
        virtual
        returns (bool)
    {
        address _hookAddr;
        uint256 _cursorFrom;
        uint256 _cursorEnd;
        (_hookAddr, _cursorFrom, _cursorEnd) = _nextHookSignature(hookSignatures, _cursorEnd);

        mapping(address => address) storage preIsValidSignatureHook = AccountStorage.layout().preIsValidSignatureHook;
        address addr = preIsValidSignatureHook[AddressLinkedList.SENTINEL_ADDRESS];
        while (uint160(addr) > AddressLinkedList.SENTINEL_UINT) {
            bytes calldata currentHookSignature;
            address hookAddress = addr;
            if (hookAddress == _hookAddr) {
                currentHookSignature = hookSignatures[_cursorFrom:_cursorEnd];
                // next
                _hookAddr = address(0);
                if (_cursorEnd > 0) {
                    (_hookAddr, _cursorFrom, _cursorEnd) = _nextHookSignature(hookSignatures, _cursorEnd);
                }
            } else {
                currentHookSignature = hookSignatures[0:0];
            }
            try IHook(addr).preIsValidSignatureHook(hash, currentHookSignature) {}
            catch {
                return false;
            }
            addr = preIsValidSignatureHook[addr];
        }

        if (_hookAddr != address(0)) {
            revert INVALID_HOOK_SIGNATURE();
        }

        return true;
    }

    function _preUserOpValidationHook(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds,
        bytes calldata hookSignatures
    ) internal virtual returns (bool) {
        address _hookAddr;
        uint256 _cursorFrom;
        uint256 _cursorEnd;
        (_hookAddr, _cursorFrom, _cursorEnd) = _nextHookSignature(hookSignatures, _cursorEnd);

        mapping(address => address) storage preUserOpValidationHook = AccountStorage.layout().preUserOpValidationHook;
        address addr = preUserOpValidationHook[AddressLinkedList.SENTINEL_ADDRESS];
        while (uint160(addr) > AddressLinkedList.SENTINEL_UINT) {
            bytes calldata currentHookSignature;
            address hookAddress = addr;
            if (hookAddress == _hookAddr) {
                currentHookSignature = hookSignatures[_cursorFrom:_cursorEnd];
                // next
                _hookAddr = address(0);
                if (_cursorEnd > 0) {
                    (_hookAddr, _cursorFrom, _cursorEnd) = _nextHookSignature(hookSignatures, _cursorEnd);
                }
            } else {
                currentHookSignature = hookSignatures[0:0];
            }
            try IHook(addr).preUserOpValidationHook(userOp, userOpHash, missingAccountFunds, currentHookSignature) {}
            catch {
                return false;
            }
            addr = preUserOpValidationHook[addr];
        }

        if (_hookAddr != address(0)) {
            revert INVALID_HOOK_SIGNATURE();
        }

        return true;
    }
}
