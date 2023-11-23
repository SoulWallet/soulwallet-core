// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UserOperation} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IPlugin is IERC165 {
    /**
     * @dev Hook that is called before any userOp is executed.
     * must revert if the userOp is invalid.
     */
    function preUserOpValidationHook(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        view;
}
