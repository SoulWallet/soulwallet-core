// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IModule} from "../interface/IModule.sol";
import {IPluggable} from "../interface/IPluggable.sol";
import {IModuleManager} from "../interface/IModuleManager.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";
import {Authority} from "./Authority.sol";
import {AddressLinkedList} from "../utils/AddressLinkedList.sol";
import {SelectorLinkedList} from "../utils/SelectorLinkedList.sol";

abstract contract ModuleManager is IModuleManager, Authority {
    using AddressLinkedList for mapping(address => address);
    using SelectorLinkedList for mapping(bytes4 => bytes4);

    error MODULE_EXECUTE_FROM_MODULE_RECURSIVE();
    error INVALID_MODULE();

    event MODULE_UNINSTALL_WITHERROR(address indexed moduleAddress);

    bytes4 private constant INTERFACE_ID_MODULE = type(IModule).interfaceId;

    function _moduleMapping() internal view returns (mapping(address => address) storage modules) {
        modules = AccountStorage.layout().modules;
    }

    function _isAuthorizedModule() internal view override returns (bool) {
        return _isAuthorizedModule(msg.sender);
    }

    function _isAuthorizedModule(address module) internal view returns (bool) {
        return _moduleMapping().isExist(module);
    }

    function isInstalledModule(address module) external view override returns (bool) {
        return _isAuthorizedModule(module);
    }

    function _installModule(bytes calldata moduleAndData, bytes4[] calldata selectors) internal virtual {
        require(selectors.length > 0);
        address moduleAddress = address(bytes20(moduleAndData[:20]));

        try IModule(moduleAddress).supportsInterface(INTERFACE_ID_MODULE) returns (bool supported) {
            if (supported == false) {
                revert INVALID_MODULE();
            }
        } catch {
            revert INVALID_MODULE();
        }

        mapping(address => address) storage modules = _moduleMapping();
        modules.add(moduleAddress);
        mapping(bytes4 => bytes4) storage moduleSelectors = AccountStorage.layout().moduleSelectors[moduleAddress];
        for (uint256 i = 0; i < selectors.length; i++) {
            moduleSelectors.add(selectors[i]);
        }
        bytes memory callData = abi.encodeWithSelector(IPluggable.Init.selector, moduleAndData[20:]);
        bytes4 invalidModuleSelector = INVALID_MODULE.selector;
        assembly ("memory-safe") {
            let result := call(gas(), moduleAddress, 0, add(callData, 0x20), mload(callData), 0x00, 0x00)
            if iszero(result) {
                mstore(0x00, invalidModuleSelector)
                revert(0x00, 4)
            }
        }
    }

    function isAuthorizedModule(address module) external view override returns (bool) {
        return _moduleMapping().isExist(module);
    }

    function installModule(bytes calldata moduleAndData, bytes4[] calldata selectors)
        external
        virtual
        override
        onlySelfOrModule
    {
        _installModule(moduleAndData, selectors);
    }

    function _uninstallModule(address moduleAddress) internal virtual {
        mapping(address => address) storage modules = _moduleMapping();
        modules.remove(moduleAddress);
        AccountStorage.layout().moduleSelectors[moduleAddress].clear();

        (bool success,) =
            moduleAddress.call{gas: 100000 /* max to 100k gas */ }(abi.encodeWithSelector(IPluggable.DeInit.selector));
        if (!success) {
            emit MODULE_UNINSTALL_WITHERROR(moduleAddress);
        }
    }

    function uninstallModule(address moduleAddress) external virtual override onlySelfOrModule {
        _uninstallModule(moduleAddress);
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

    function executeFromModule(address dest, uint256 value, bytes memory func) external virtual override {
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
