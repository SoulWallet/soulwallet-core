// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAccount, UserOperation} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {EntryPointManager} from "./base/EntryPointManager.sol";
import {FallbackManager} from "./base/FallbackManager.sol";
import {ModuleManager} from "./base/ModuleManager.sol";
import {OwnerManager} from "./base/OwnerManager.sol";
import {StandardExecutor} from "./base/StandardExecutor.sol";
import {ValidatorManager} from "./base/ValidatorManager.sol";
import {HookManager} from "./base/HookManager.sol";
import {SignatureDecoder} from "./utils/SignatureDecoder.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";

contract LightAccount is
    IAccount,
    IERC1271,
    EntryPointManager,
    OwnerManager,
    ModuleManager,
    HookManager,
    StandardExecutor,
    ValidatorManager,
    FallbackManager
{
    constructor(address _entryPoint) EntryPointManager(_entryPoint) {}

    function isValidSignature(bytes32 hash, bytes calldata signature)
        public
        view
        virtual
        override
        returns (bytes4 magicValue)
    {
        (address validator, bytes calldata validatorSignature, bytes calldata hookSignature) =
            SignatureDecoder.signatureSplit(signature);

        if (_preIsValidSignatureHook(hash, hookSignature) == false) return bytes4(0);
        return _isValidSignature(hash, validator, validatorSignature);
    }

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        public
        virtual
        override
        onlyEntryPoint
        returns (uint256 validationData)
    {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }

        (address validator, bytes calldata validatorSignature, bytes calldata hookSignature) =
            SignatureDecoder.signatureSplit(userOp.signature);

        if (_preUserOpValidationHook(userOp, userOpHash, missingAccountFunds, hookSignature) == false) {
            return SIG_VALIDATION_FAILED;
        }
        validationData = _validateUserOp(userOp, userOpHash, validator, validatorSignature);
    }
}
