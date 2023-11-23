// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPluginManager {
    function installPlugin(address plugin) external;
    function uninstallPlugin(address plugin) external;

    function listPlugin() external view returns (address[] memory plugins);
}
