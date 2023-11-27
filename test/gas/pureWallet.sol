// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LightAccount} from "@source/LightAccount.sol";

contract PureWallet is LightAccount {
    uint256 private _initialized;

    constructor(address _entryPoint) LightAccount(_entryPoint) {
        require(_initialized == 0);
        _initialized = 1;
    }

    function initialize(bytes32[] memory _owners, address defaultValidator, address defaultFallback) external {
        require(_initialized == 0);
        for (uint256 i = 0; i < _owners.length; i++) {
            _addOwner(_owners[i]);
        }
        _installValidator(defaultValidator);
        _setFallbackHandler(defaultFallback);

        _initialized = 1;
    }
}
