// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Authority} from "./Authority.sol";
import {IValidatorManager} from "../interface/IValidatorManager.sol";
import {IValidator} from "../interface/IValidator.sol";
import {UserOperation} from "../interface/IAccount.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";
import {AddressLinkedList} from "../utils/AddressLinkedList.sol";

abstract contract ValidatorManager is Authority, IValidatorManager {
    using AddressLinkedList for mapping(address => address);

    error INVALID_VALIDATOR();

    //return value in case of signature failure, with no time-range.
    // equivalent to _packValidationData(true,0,0);
    uint256 internal constant SIG_VALIDATION_FAILED = 1;

    bytes4 private constant INTERFACE_ID_VALIDATOR = type(IValidator).interfaceId;

    function _installValidator(address validator) internal virtual {
        try IValidator(validator).supportsInterface(INTERFACE_ID_VALIDATOR) returns (bool supported) {
            if (supported == false) {
                revert INVALID_VALIDATOR();
            } else {
                AccountStorage.layout().validators.add(address(validator));
            }
        } catch {
            revert INVALID_VALIDATOR();
        }
    }

    function _uninstallValidator(address validator) internal virtual {
        AccountStorage.layout().validators.remove(address(validator));
    }

    function _resetValidator(address validator) internal virtual {
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
        returns (bytes4 magicValue)
    {
        if (AccountStorage.layout().validators.isExist(validator) == false) {
            return bytes4(0);
        }
        bytes memory callData = abi.encodeWithSelector(IValidator.isValidSignature.selector, hash, validatorSignature);
        assembly ("memory-safe") {
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
    ) internal virtual returns (uint256 validationData) {
        if (AccountStorage.layout().validators.isExist(validator) == false) {
            return SIG_VALIDATION_FAILED;
        }
        bytes memory callData =
            abi.encodeWithSelector(IValidator.validateUserOp.selector, userOp, userOpHash, validatorSignature);

        assembly ("memory-safe") {
            let result := call(gas(), validator, 0, add(callData, 0x20), mload(callData), 0x00, 0x20)
            if iszero(result) {
                mstore(0x00, SIG_VALIDATION_FAILED)
                return(0x00, 0x20)
            }
            validationData := mload(0x00)
        }
    }
}
