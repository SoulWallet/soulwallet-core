// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHookManager {
    function installHook(address hook) external;
    function uninstallHook(address hook) external;

    function listHook() external view returns (address[] memory hooks);
}
