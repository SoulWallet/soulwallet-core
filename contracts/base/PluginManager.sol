// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Authority} from "./Authority.sol";
import {IPluginManager} from "../interface/IPluginManager.sol";
import {IPlugin} from "../interface/IPlugin.sol";
import {IAccount, UserOperation} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {AccountStorage} from "../utils/AccountStorage.sol";
import {AddressLinkedList} from "../utils/AddressLinkedList.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";

abstract contract PluginManager is Authority, IPluginManager, IERC1271 {
    using AddressLinkedList for mapping(address => address);

    error INVALID_PLUGIN();

    bytes4 private constant INTERFACE_ID_PLUGIN = type(IPlugin).interfaceId;

    function _pluginMapping() internal view returns (mapping(address => address) storage plugins) {
        plugins = AccountStorage.layout().plugins;
    }

    function _installPlugin(address plugin) internal virtual {
        try IPlugin(plugin).supportsInterface(INTERFACE_ID_PLUGIN) returns (bool supported) {
            if (supported == false) {
                revert INVALID_PLUGIN();
            } else {
                _pluginMapping().add(plugin);
            }
        } catch {
            revert INVALID_PLUGIN();
        }
    }

    function _uninstallPlugin(address plugin) internal virtual {
        _pluginMapping().remove(plugin);
    }

    function _cleanPlugin() internal virtual {
        _pluginMapping().clear();
    }

    function installPlugin(address plugin) external virtual override onlySelfOrModule {
        _installPlugin(plugin);
    }

    function uninstallPlugin(address plugin) external virtual override onlySelfOrModule {
        _uninstallPlugin(plugin);
    }

    function listPlugin() external view virtual override returns (address[] memory plugins) {}

    function _preValidateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        internal
        view
        virtual
        returns (bool isValid)
    {
        revert("Not implemented");
    }
}
