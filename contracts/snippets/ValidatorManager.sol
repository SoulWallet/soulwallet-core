// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UserOperation} from "../interface/IAccount.sol";

abstract contract ValidatorManagerBase {
    /**
     * @dev checks whether a address is a installed validator
     */
    function _isInstalledValidator(address validator) internal view virtual returns (bool);

    /**
     * @dev install a validator
     */
    function _installValidator(address validator) internal virtual;

    /**
     * @dev uninstall a validator
     */
    function _uninstallValidator(address validator) internal virtual;

    /**
     * @dev reset validator
     */
    function _resetValidator(address validator) internal virtual;

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
        returns (bytes4 magicValue);

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
    ) internal virtual returns (uint256 validationData);
}
