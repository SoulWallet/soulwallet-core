// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStandardExecutor, Execution} from "../interface/IStandardExecutor.sol";
import {EntryPointManager} from "./EntryPointManager.sol";

abstract contract StandardExecutor is IStandardExecutor, EntryPointManager {
    function execute(address target, uint256 value, bytes calldata data)
        external
        payable
        virtual
        override
        onlyEntryPoint
    {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, data.offset, data.length)
            let result := call(gas(), target, value, ptr, data.length, 0, 0)
            if iszero(result) {
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }

    function executeBatch(Execution[] calldata executions) external payable virtual override onlyEntryPoint {
        for (uint256 i = 0; i < executions.length; i++) {
            Execution calldata execution = executions[i];
            address target = execution.target;
            uint256 value = execution.value;
            bytes calldata data = execution.data;

            assembly ("memory-safe") {
                let ptr := mload(0x40)
                calldatacopy(ptr, data.offset, data.length)
                let result := call(gas(), target, value, ptr, data.length, 0, 0)
                if iszero(result) {
                    returndatacopy(ptr, 0, returndatasize())
                    revert(ptr, returndatasize())
                }
            }
        }
    }
}
