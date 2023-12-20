// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Authority} from "./Authority.sol";
import {IValidatorManager} from "../interface/IValidatorManager.sol";
import {IValidator} from "../interface/IValidator.sol";
import {UserOperation} from "../interface/IAccount.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";
import {AddressLinkedList} from "../utils/AddressLinkedList.sol";
import {SIG_VALIDATION_FAILED} from "../utils/Constants.sol";
import {ValidatorManagerSnippet} from "../snippets/ValidatorManager.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

abstract contract ValidatorManager is Authority, IValidatorManager, ValidatorManagerSnippet {
    using AddressLinkedList for mapping(address => address);

    error INVALID_VALIDATOR();

    bytes4 private constant INTERFACE_ID_VALIDATOR = type(IValidator).interfaceId;

    /**
     * @dev checks whether a address is a installed validator
     */
    function _isInstalledValidator(address validator) internal view virtual override returns (bool) {
        return AccountStorage.layout().validators.isExist(validator);
    }

    /**
     * @dev checks whether a address is a valid validator
     * note: If you need to extend the interface, override this function
     * @param validator validator address
     */
    function _isSupportsValidatorInterface(address validator) internal view virtual override returns (bool supported) {
        bytes memory callData = abi.encodeWithSelector(IERC165.supportsInterface.selector, INTERFACE_ID_VALIDATOR);
        assembly ("memory-safe") {
            // memorySafe: The scratch space between memory offset 0 and 64.

            let result := staticcall(gas(), validator, add(callData, 0x20), mload(callData), 0x00, 0x20)
            if gt(result, 0) { supported := mload(0x00) }
        }
    }

    /**
     * @dev install a validator
     */
    function _installValidator(address validator) internal virtual override {
        if (_isSupportsValidatorInterface(validator) == false) {
            revert INVALID_VALIDATOR();
        }
        AccountStorage.layout().validators.add(address(validator));
    }

    /**
     * @dev uninstall a validator
     */
    function _uninstallValidator(address validator) internal virtual override {
        AccountStorage.layout().validators.remove(address(validator));
    }

    /**
     * @dev reset validator
     */
    function _resetValidator(address validator) internal virtual override {
        AccountStorage.layout().validators.clear();
        _installValidator(validator);
    }

    /**
     * @dev install a validator
     */
    function installValidator(address validator) external virtual override {
        validatorManagementAccess();
        _installValidator(validator);
    }

    /**
     * @dev uninstall a validator
     */
    function uninstallValidator(address validator) external virtual override {
        validatorManagementAccess();
        _uninstallValidator(validator);
    }

    /**
     * @dev list validators
     */
    function listValidator() external view virtual override returns (address[] memory validators) {
        mapping(address => address) storage validator = AccountStorage.layout().validators;
        validators = validator.list(AddressLinkedList.SENTINEL_ADDRESS, validator.size());
    }

    /**
     * @dev EIP-1271
     * @param hash hash of the data to be signed
     * @param validator validator address
     * @param validatorSignature Signature byte array associated with _data
     * @return magicValue Magic value 0x1626ba7e if the validator is registered and signature is valid
     */
    function _isValidSignature(bytes32 hash, address validator, bytes calldata validatorSignature)
        internal
        view
        virtual
        override
        returns (bytes4 magicValue)
    {
        if (_isInstalledValidator(validator) == false) {
            return bytes4(0);
        }
        bytes memory callData = abi.encodeWithSelector(IValidator.validateSignature.selector, hash, validatorSignature);
        assembly ("memory-safe") {
            // memorySafe: The scratch space between memory offset 0 and 64.

            let result := staticcall(gas(), validator, add(callData, 0x20), mload(callData), 0x00, 0x20)
            if result { magicValue := mload(0x00) }
        }
    }

    /**
     * @dev validate UserOperation
     * @param userOp UserOperation
     * @param userOpHash UserOperation hash
     * @param validator validator address
     * @param validatorSignature validator signature
     * @return validationData refer to https://github.com/eth-infinitism/account-abstraction/blob/v0.6.0/contracts/interfaces/IAccount.sol#L24-L30
     */
    function _validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        address validator,
        bytes calldata validatorSignature
    ) internal virtual override returns (uint256 validationData) {
        if (_isInstalledValidator(validator) == false) {
            return SIG_VALIDATION_FAILED;
        }
        bytes memory callData =
            abi.encodeWithSelector(IValidator.validateUserOp.selector, userOp, userOpHash, validatorSignature);

        assembly ("memory-safe") {
            // memorySafe: The scratch space between memory offset 0 and 64.

            let result := call(gas(), validator, 0, add(callData, 0x20), mload(callData), 0x00, 0x20)
            if iszero(result) { mstore(0x00, SIG_VALIDATION_FAILED) }
            validationData := mload(0x00)
        }
    }
}
