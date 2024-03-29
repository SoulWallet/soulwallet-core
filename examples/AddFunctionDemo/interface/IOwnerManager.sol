// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IOwnerManager {
    function addOwners(bytes32[] calldata owner) external;
    function removeOwners(bytes32[] calldata owner) external;
}
