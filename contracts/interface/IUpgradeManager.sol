// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUpgradeManager {
    function upgradeTo(address newImplementation) external;
}
