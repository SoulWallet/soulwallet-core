// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UserOperation} from "../interface/IAccount.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IHook is IERC165 {
    /**
     * @dev Should return whether the signature provided is valid for the provided data
     * @param hash      Hash of the data to be signed
     * @param hookSignature Signature byte array associated with _data
     */
    function preIsValidSignatureHook(bytes32 hash, bytes calldata hookSignature) external view;

    /**
     * @dev Hook that is called before any userOp is executed.
     * must revert if the userOp is invalid.
     */
    function preUserOpValidationHook(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds,
        bytes calldata hookSignature
    ) external;
}
