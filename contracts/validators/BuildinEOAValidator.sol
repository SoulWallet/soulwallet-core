// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IValidator} from "../interface/IValidator.sol";
import {UserOperation} from "../interface/IAccount.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IOwnable} from "../interface/IOwnable.sol";

contract BuildinEOAValidator is IValidator {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // Magic value indicating a valid signature for ERC-1271 contracts
    bytes4 private constant MAGICVALUE = bytes4(keccak256("isValidSignature(bytes32,bytes)"));

    bytes4 private constant INTERFACE_ID_VALIDATOR = type(IValidator).interfaceId;

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == INTERFACE_ID_VALIDATOR;
    }

    function _packHash(bytes32 hash) internal view returns (bytes32) {
        uint256 _chainid;
        assembly {
            _chainid := chainid()
        }
        address account = msg.sender;
        return keccak256(abi.encode(hash, account, _chainid));
    }

    function isValidSignature(bytes32 hash, bytes calldata validatorSignature)
        external
        view
        override
        returns (bytes4 magicValue)
    {
        (address recoveredAddr, ECDSA.RecoverError error,) =
            ECDSA.tryRecover(_packHash(hash).toEthSignedMessageHash(), validatorSignature);
        if (error != ECDSA.RecoverError.NoError) {
            return bytes4(0);
        }
        try IOwnable(msg.sender).isOwner(bytes32(uint256(uint160(recoveredAddr)))) returns (bool result) {
            if (result) {
                return MAGICVALUE;
            }
            return bytes4(0);
        } catch {
            return bytes4(0);
        }
    }

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, bytes calldata validatorSignature)
        external
        view
        override
        returns (uint256 validationData)
    {
        (userOp);
        (address recoveredAddr, ECDSA.RecoverError error,) =
            ECDSA.tryRecover(_packHash(userOpHash).toEthSignedMessageHash(), validatorSignature);
        if (error != ECDSA.RecoverError.NoError) {
            return 1;
        }
        try IOwnable(msg.sender).isOwner(bytes32(uint256(uint160(recoveredAddr)))) returns (bool result) {
            if (result) {
                return 0;
            }
            return 1;
        } catch {
            return 1;
        }
    }
}
