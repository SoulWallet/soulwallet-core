// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IOwnerManager} from "@source/interface/IOwnerManager.sol";
import {BasicModularAccount} from "../examples/BasicModularAccount.sol";
import {Execution} from "@source/interface/IStandardExecutor.sol";
import "@source/validators/EOAValidator.sol";
import {ReceiverHandler} from "./dev/ReceiverHandler.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {DeployEntryPoint} from "./dev/deployEntryPoint.sol";
import {SoulWalletFactory} from "./dev/SoulWalletFactory.sol";

contract EIP1271Test is Test {
    using MessageHashUtils for bytes32;

    SoulWalletFactory walletFactory;
    BasicModularAccount walletImpl;

    EOAValidator validator;
    ReceiverHandler _fallback;

    address public walletOwner;
    uint256 public walletOwnerPrivateKey;

    BasicModularAccount wallet;

    function setUp() public {
        walletImpl = new BasicModularAccount(address(this));
        walletFactory = new SoulWalletFactory(address(walletImpl), address(this), address(this));
        validator = new EOAValidator();
        _fallback = new ReceiverHandler();
        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("owner1");

        bytes32 salt = 0;
        bytes memory initializer;
        {
            bytes32 owner = bytes32(uint256(uint160(walletOwner)));
            address defaultValidator = address(validator);
            address defaultFallback = address(_fallback);
            initializer = abi.encodeWithSelector(
                BasicModularAccount.initialize.selector, owner, defaultValidator, defaultFallback
            );
        }

        wallet = BasicModularAccount(payable(walletFactory.createWallet(initializer, salt)));
    }

    event InitCalled(bytes data);
    event DeInitCalled();

    error CALLER_MUST_BE_SELF_OR_MODULE();

    function _packHash(address account, bytes32 hash) private view returns (bytes32) {
        uint256 _chainid;
        assembly {
            _chainid := chainid()
        }
        return keccak256(abi.encode(hash, account, _chainid));
    }

    function _packSignature(address validatorAddress, bytes memory signature) private pure returns (bytes memory) {
        uint32 sigLen = uint32(signature.length);
        return abi.encodePacked(validatorAddress, sigLen, signature);
    }

    function signMsg(address sender, bytes32 hash) private view returns (bytes memory signature) {
        bytes32 _hash = _packHash(sender, hash).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(walletOwnerPrivateKey, _hash);
        return _packSignature(address(validator), abi.encodePacked(r, s, v));
    }

    bytes4 private constant MAGICVALUE = bytes4(keccak256("isValidSignature(bytes32,bytes)"));

    function test_EIP1271() public {
        bytes32 hash1 = keccak256("test1");
        bytes32 hash2 = keccak256("test2");
        bytes memory signature1 = signMsg(address(wallet), hash1);
        bytes memory signature2 = signMsg(address(wallet), hash2);

        assertEq(wallet.isValidSignature(hash1, signature1), MAGICVALUE);
        assertEq(wallet.isValidSignature(hash2, signature2), MAGICVALUE);
        assertEq(wallet.isValidSignature(hash1, signature2), bytes4(0));
    }
}
