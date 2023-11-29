// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Authority {
    /**
     * a custom error for caller must be self or module
     */
    error CALLER_MUST_BE_SELF_OR_MODULE();

    /**
     * a custom error for caller must be module
     */
    error CALLER_MUST_BE_MODULE();

    /**
     * @dev checks whether the caller is the Authority contract
     */
    function _isAuthorizedModule() internal view virtual returns (bool);

    /**
     * @notice Ensures the calling contract is the entrypoint
     */
    function _onlyEntryPoint() internal view virtual;

    /**
     * @notice Ensures the calling contract is an authorized module
     */
    function _onlyModule() internal view {
        if (!_isAuthorizedModule()) {
            revert CALLER_MUST_BE_MODULE();
        }
    }

    /**
     * @notice Ensures the calling contract is either the Authority contract itself or an authorized module
     * @dev Uses the inherited `_isAuthorizedModule()` from ModuleAuth for module-based authentication
     */
    function _onlySelfOrModule() internal view {
        if (msg.sender != address(this) && !_isAuthorizedModule()) {
            revert CALLER_MUST_BE_SELF_OR_MODULE();
        }
    }

    /**
     * @dev Check if access to the following functions:
     *      1. setFallbackHandler
     */
    function fallbackManagementAccess() internal view virtual {
        _onlySelfOrModule();
    }

    /**
     * @dev Check if access to the following functions:
     *      1. installHook
     *      2. uninstallHook
     *      3. installModule
     *      4. uninstallModule
     */
    function pluginManagementAccess() internal view virtual {
        _onlySelfOrModule();
    }

    /**
     * @dev Check if access to the following functions:
     *      1. addOwner
     *      2. removeOwner
     *      3. resetOwner
     */
    function ownerManagementAccess() internal view virtual {
        _onlySelfOrModule();
    }

    /**
     * @dev Check if access to the following functions:
     *      1. execute
     *      2. executeBatch
     */
    function executorAccess() internal view virtual {
        _onlyEntryPoint();
    }

    /**
     * @dev Check if access to the following functions:
     *      1. installValidator
     *      2. uninstallValidator
     */
    function validatorManagementAccess() internal view virtual {
        _onlySelfOrModule();
    }
}
