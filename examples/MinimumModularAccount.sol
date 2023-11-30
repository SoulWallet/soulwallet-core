// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SoulWalletCore} from "../contracts/SoulWalletCore.sol";
import {BuildinEOAValidator} from "../contracts/validators/BuildinEOAValidator.sol";

contract MinimumAccount is SoulWalletCore, BuildinEOAValidator {
    uint256 private _initialized;

    modifier initializer() {
        require(_initialized == 0);
        _initialized = 1;
        _;
    }

    constructor(address _entryPoint) SoulWalletCore(_entryPoint) initializer {}

    function initialize(bytes32 owner) external initializer {
        _addOwner(owner);
        _installValidator(this);
    }
}
