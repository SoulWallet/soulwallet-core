// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IValidatorManager {
    function installValidator(address validator, bytes calldata) external;
}
