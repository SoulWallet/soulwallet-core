// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISignatureRecover {
    function recover(bytes32 hash, bytes calldata signature) external view returns (bytes32 recovered, bool success);
}
