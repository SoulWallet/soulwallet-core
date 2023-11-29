// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Authority} from "./Authority.sol";
import {IStandardExecutor, Execution} from "../interface/IStandardExecutor.sol";
import {EntryPointManager} from "./EntryPointManager.sol";

abstract contract StandardExecutor is Authority, IStandardExecutor, EntryPointManager {
    /**
     * @dev execute method
     * only entrypoint can call this method
     * @param target the target address
     * @param value the value
     * @param data the data
     */
    function execute(address target, uint256 value, bytes calldata data) external payable virtual override {
        executorAccess();
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

    /**
     * @dev execute batch method
     * only entrypoint can call this method
     * @param executions the executions
     */
    function executeBatch(Execution[] calldata executions) external payable virtual override {
        executorAccess();
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
