// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAccount, UserOperation} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {EntryPointManager} from "./base/EntryPointManager.sol";
import {FallbackManager} from "./base/FallbackManager.sol";
import {ModuleManager} from "./base/ModuleManager.sol";
import {OwnerManager} from "./base/OwnerManager.sol";
import {StandardExecutor} from "./base/StandardExecutor.sol";
import {ValidatorManager} from "./base/ValidatorManager.sol";
import {PluginManager} from "./base/PluginManager.sol";
import {AccountStorage} from "./utils/AccountStorage.sol";

contract LightAccount is
    IAccount,
    EntryPointManager,
    FallbackManager,
    ModuleManager,
    OwnerManager,
    StandardExecutor,
    ValidatorManager,
    PluginManager
{
    constructor(address _entryPoint) EntryPointManager(_entryPoint) {}

    function _isAuthorizedModule() internal view override returns (bool) {
        return __isAuthorizedModule();
    }

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        view
        virtual
        override
        returns (uint256 validationData)
    {
        if (_preValidateUserOp(userOp, userOpHash, missingAccountFunds) == false) return SIG_VALIDATION_FAILED;
        address validator = address(bytes20(userOp.signature[0:20]));
        validationData = _validateUserOp(validator, userOp, userOpHash, missingAccountFunds);
    }
}
