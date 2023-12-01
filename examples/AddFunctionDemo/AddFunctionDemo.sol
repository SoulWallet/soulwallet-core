// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SoulWalletCore} from "../../contracts/SoulWalletCore.sol";
import {OwnerManager} from "./base/OwnerManager.sol";

contract AddFunctionDemo is SoulWalletCore, OwnerManager {
    uint256 private _initialized;

    modifier initializer() {
        require(_initialized == 0);
        _initialized = 1;
        _;
    }

    constructor(address _entryPoint) SoulWalletCore(_entryPoint) initializer {}

    function initialize(bytes32 owner, address validator, address defaultFallback) external initializer {
        _addOwner(owner);
        _installValidator(validator);
        _setFallbackHandler(defaultFallback);
    }
}
