// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IModule} from "../interface/IModule.sol";
import {IModuleManager} from "../interface/IModuleManager.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";
import {Authority} from "./Authority.sol";

abstract contract ModuleManager is IModuleManager, Authority {
    function __isAuthorizedModule() internal view returns (bool) {
        revert("Not implemented");
    }

    function installModule(IModule module, bytes calldata data) external virtual override onlySelfOrModule {
        revert("Not implemented");
    }

    function uninstallModule(IModule module, bytes calldata data) external virtual override onlySelfOrModule {
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
