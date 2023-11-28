// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LightAccount} from "./LightAccount.sol";

contract SoulWallet is LightAccount {
    address internal immutable _DEFAULT_VALIDATOR;

    constructor(address _entryPoint, bytes32[] memory _owners, address defaultValidator) LightAccount(_entryPoint) {
        for (uint256 i = 0; i < _owners.length; i++) {
            _addOwner(_owners[i]);
        }
        _DEFAULT_VALIDATOR = defaultValidator;
        _installValidator(defaultValidator);
    }

    function _uninstallValidator(address validator) internal override {
        require(validator != _DEFAULT_VALIDATOR, "can't uninstall default validator");
        super._uninstallValidator(validator);
    }

    function _resetValidator(address validator) internal override {
        require(validator == _DEFAULT_VALIDATOR, "can't uninstall default validator");
        super._resetValidator(validator);
    }

    /**
     *  disable Module
     */
    function installModule(bytes calldata moduleAndData, bytes4[] calldata selectors) external pure override {
        (moduleAndData, selectors);
        revert("disabled");
    }
}
