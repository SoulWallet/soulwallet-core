// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Authority} from "./Authority.sol";
import {IValidatorManager} from "../interface/IValidatorManager.sol";
import {IValidator} from "../interface/IValidator.sol";
import {UserOperation} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";
import {AddressLinkedList} from "../utils/AddressLinkedList.sol";

abstract contract ValidatorManager is Authority, IValidatorManager {
    using AddressLinkedList for mapping(address => address);

    error INVALID_VALIDATOR();

    //return value in case of signature failure, with no time-range.
    // equivalent to _packValidationData(true,0,0);
    uint256 internal constant SIG_VALIDATION_FAILED = 1;

    bytes4 private constant INTERFACE_ID_VALIDATOR = type(IValidator).interfaceId;

    function _validatorMapping() internal view returns (mapping(address => address) storage validator) {
        validator = AccountStorage.layout().validators;
    }

    function _installValidator(address validator) internal virtual {
        try IValidator(validator).supportsInterface(INTERFACE_ID_VALIDATOR) returns (bool supported) {
            if (supported == false) {
                revert INVALID_VALIDATOR();
            } else {
                _validatorMapping().add(address(validator));
            }
        } catch {
            revert INVALID_VALIDATOR();
        }
    }

    function _uninstallValidator(address validator) internal virtual {
        _validatorMapping().remove(address(validator));
    }

    function _resetValidator(address validator) internal virtual {
        _validatorMapping().clear();
        _installValidator(validator);
    }

    function installValidator(address validator) external virtual override onlySelfOrModule {
        _installValidator(validator);
    }

    function uninstallValidator(address validator) external virtual override onlySelfOrModule {
        _uninstallValidator(validator);
    }

    function listValidator() external view virtual override returns (address[] memory validators) {
        mapping(address => address) storage validator = _validatorMapping();
        validators = validator.list(AddressLinkedList.SENTINEL_ADDRESS, validator.size());
    }

    function _isValidSignature(bytes32 hash, address validator, bytes calldata validatorSignature)
        internal
        view
        virtual
        returns (bytes4 magicValue)
    {
        if (_validatorMapping().isExist(validator) == false) {
            return bytes4(0);
        }
        try IValidator(validator).isValidSignature(hash, validatorSignature) returns (bytes4 _magicValue) {
            return _magicValue;
        } catch {
            return bytes4(0);
        }
    }

    function _validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        address validator,
        bytes calldata validatorSignature
    ) internal view virtual returns (uint256 validationData) {
        if (_validatorMapping().isExist(validator) == false) {
            return SIG_VALIDATION_FAILED;
        }
        try IValidator(validator).validateUserOp(userOp, userOpHash, validatorSignature) returns (
            uint256 _validationData
        ) {
            return _validationData;
        } catch {
            return SIG_VALIDATION_FAILED;
        }
    }
}
