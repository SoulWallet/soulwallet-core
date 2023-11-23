// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IValidator} from "./IValidator.sol";

interface IValidatorManager {
    function installValidator(IValidator validator) external;

    function uninstallValidator(IValidator validator) external;

    function listValidator() external view returns (address[] memory validators);
}
