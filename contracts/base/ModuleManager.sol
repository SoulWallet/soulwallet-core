// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IModuleManager} from "../interface/IModuleManager.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";
import {Authority} from "./Authority.sol";
import {AddressLinkedList} from "../utils/AddressLinkedList.sol";
import {SelectorLinkedList} from "../utils/SelectorLinkedList.sol";

abstract contract ModuleManager is IModuleManager, Authority {
    using AddressLinkedList for mapping(address => address);
    using SelectorLinkedList for mapping(bytes4 => bytes4);

    function _moduleMapping() internal view returns (mapping(address => address) storage modules) {
        modules = AccountStorage.layout().modules;
    }

    function __isAuthorizedModule() internal view returns (bool) {
        revert("Not implemented");
    }

    function installModule(address module, bytes4[] calldata selectors) external virtual override onlySelfOrModule {
        mapping(address => address) storage modules = _moduleMapping();
        modules.add(module);
        mapping(bytes4 => bytes4) storage moduleSelectors = AccountStorage.layout().moduleSelectors[module];
        for (uint256 i = 0; i < selectors.length; i++) {
            moduleSelectors.add(selectors[i]);
        }
    }

    function uninstallModule(address module) external virtual override onlySelfOrModule {
        revert("Not implemented");
    }

    function listModule()
        external
        view
        virtual
        override
        returns (address[] memory modules, bytes4[][] memory selectors)
    {
        revert("Not implemented");
    }

    function executeFromModule(address dest, uint256 value, bytes calldata func) external virtual override {
        require(_isAuthorizedModule());

        revert("Not implemented");
    }
}
