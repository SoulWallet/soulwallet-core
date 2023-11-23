// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LightAccount} from "./LightAccount.sol";

contract SoulWallet is LightAccount {
    constructor(address _entryPoint) LightAccount(_entryPoint) {}

    /**
     * demo: disable ModuleManager demo
     */
    function installModule(address module, bytes4[] calldata selectors) external pure override {
        (module, selectors);
        revert("disabled");
    }
}
