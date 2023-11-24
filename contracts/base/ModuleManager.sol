// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IModuleManager} from "../interface/IModuleManager.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";
import {Authority} from "./Authority.sol";
import {AddressLinkedList} from "../utils/AddressLinkedList.sol";
import {SelectorLinkedList} from "../utils/SelectorLinkedList.sol";

abstract contract ModuleManager is IModuleManager, Authority {
    using AddressLinkedList for mapping(address => address);
    using SelectorLinkedList for mapping(bytes4 => bytes4);

    error MODULE_EXECUTE_FROM_MODULE_RECURSIVE();

    function _moduleMapping() internal view returns (mapping(address => address) storage modules) {
        modules = AccountStorage.layout().modules;
    }

    function _isAuthorizedModule() internal view override returns (bool) {
        address module = msg.sender;
        if (!_moduleMapping().isExist(module)) {
            return false;
        }
        mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors = AccountStorage.layout().moduleSelectors;
        return moduleSelectors[module].isExist(msg.sig);
    }

    function _installModule(address module, bytes4[] calldata selectors) internal virtual {
        require(selectors.length > 0);
        mapping(address => address) storage modules = _moduleMapping();
        modules.add(module);
        mapping(bytes4 => bytes4) storage moduleSelectors = AccountStorage.layout().moduleSelectors[module];
        for (uint256 i = 0; i < selectors.length; i++) {
            moduleSelectors.add(selectors[i]);
        }
    }

    function installModule(address module, bytes4[] calldata selectors) external virtual override onlySelfOrModule {
        _installModule(module, selectors);
    }

    function _uninstallModule(address module) internal virtual {
        mapping(address => address) storage modules = _moduleMapping();
        modules.remove(module);
        AccountStorage.layout().moduleSelectors[module].clear();
    }

    function uninstallModule(address module) external virtual override onlySelfOrModule {
        _uninstallModule(module);
    }

    function listModule()
        external
        view
        virtual
        override
        returns (address[] memory modules, bytes4[][] memory selectors)
    {
        mapping(address => address) storage _modules = _moduleMapping();
        uint256 moduleSize = _moduleMapping().size();
        modules = new address[](moduleSize);
        mapping(address => mapping(bytes4 => bytes4)) storage moduleSelectors = AccountStorage.layout().moduleSelectors;
        selectors = new bytes4[][](moduleSize);

        uint256 i = 0;
        address addr = _modules[AddressLinkedList.SENTINEL_ADDRESS];
        while (uint160(addr) > AddressLinkedList.SENTINEL_UINT) {
            {
                modules[i] = addr;
                mapping(bytes4 => bytes4) storage moduleSelector = moduleSelectors[addr];

                {
                    uint256 selectorSize = moduleSelector.size();
                    bytes4[] memory _selectors = new bytes4[](selectorSize);
                    uint256 j = 0;
                    bytes4 selector = moduleSelector[SelectorLinkedList.SENTINEL_SELECTOR];
                    while (uint32(selector) > SelectorLinkedList.SENTINEL_UINT) {
                        _selectors[j] = selector;

                        selector = moduleSelector[selector];
                        unchecked {
                            j++;
                        }
                    }
                    selectors[i] = _selectors;
                }
            }

            addr = _modules[addr];
            unchecked {
                i++;
            }
        }
    }

    function executeFromModule(address dest, uint256 value, bytes memory func) public virtual override {
        require(_isAuthorizedModule());

        if (dest == address(this)) revert MODULE_EXECUTE_FROM_MODULE_RECURSIVE();
        assembly {
            /* not memory-safe */
            let result := call(gas(), dest, value, add(func, 0x20), mload(func), 0, 0)
            if iszero(result) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
