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
     * Only authorized modules can manage hooks and modules.
     */
    function pluginManagementAccess() internal view override {
        _onlyModule();
    }

    /**
     * Only specific addresses can manage the owner
     * (e.g. only allowing management of the owner through an MPC wallet)
     */
    function ownerManagementAccess() internal view override {
        require(msg.sender == address(1), /* Assuming address(1) is an MPC wallet */ "caller must be entry point");
    }
}
