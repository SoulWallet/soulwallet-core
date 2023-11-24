// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Authority {
    error CALLER_MUST_BE_SELF_OR_MODULE();

    function _isAuthorizedModule() internal view virtual returns (bool);

    /**
     * @notice Ensures the calling contract is either the Authority contract itself or an authorized module
     * @dev Uses the inherited `_isAuthorizedModule()` from ModuleAuth for module-based authentication
     */
    modifier onlySelfOrModule() {
        if (msg.sender != address(this) && !_isAuthorizedModule()) {
            revert CALLER_MUST_BE_SELF_OR_MODULE();
        }
        _;
    }
}
