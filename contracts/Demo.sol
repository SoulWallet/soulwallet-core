// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LightAccount} from "./LightAccount.sol";
import {IModule} from "./interface/IModule.sol";

contract SoulWallet is LightAccount {
    constructor(address _entryPoint) LightAccount(_entryPoint) {}

    /**
     * demo: disable ModuleManager demo
     */
    function installModule(IModule module, bytes calldata data) external pure override {
        (module, data);
        revert("disabled");
    }
}
