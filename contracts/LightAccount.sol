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

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";

contract LightAccount is
    IAccount,
    IERC1271,
    EntryPointManager,
    FallbackManager,
    ModuleManager,
    OwnerManager,
    StandardExecutor,
    ValidatorManager,
    HookManager
{
    constructor(address _entryPoint) EntryPointManager(_entryPoint) {}

    function _isAuthorizedModule() internal view override returns (bool) {
        return __isAuthorizedModule();
    }

    function isValidSignature(bytes32 hash, bytes calldata signature)
        external
        view
        virtual
        override
        returns (bytes4 magicValue)
    {
        if (_preIsValidSignatureHook(hash, signature) == false) return bytes4(0);
        return _isValidSignature(hash, signature);
    }

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        virtual
        override
        onlyEntryPoint
        returns (uint256 validationData)
    {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }

        if (_preUserOpValidationHook(userOp, userOpHash, missingAccountFunds) == false) return SIG_VALIDATION_FAILED;
        validationData = _validateUserOp(userOp, userOpHash);
    }
}
