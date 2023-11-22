// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract EntryPointManager {
    address internal immutable _ENTRY_POINT;

    constructor(address _entryPoint) {
        _ENTRY_POINT = _entryPoint;
    }

    function entryPoint() external view returns (address) {
        return _ENTRY_POINT;
    }
}
