// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./pureWallet.sol";
import "@source/validators/BuildinEOAValidator.sol";
import {ReceiverHandler} from "./ReceiverHandler.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract GasCheckerTest is Test {
    using MessageHashUtils for bytes32;

    PureWallet wallet;
    BuildinEOAValidator validator;
    ReceiverHandler _fallback;

    address public walletOwner;
    uint256 public walletOwnerPrivateKey;

    function setUp() public {
        wallet = new PureWallet(address(this));
        validator = new BuildinEOAValidator();
        _fallback = new ReceiverHandler();

        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("owner");
    }

    function testDeploy() public {
        bytes32[] memory owners = new bytes32[](2);
        owners[0] = bytes32(uint256(uint160(walletOwner)));
        owners[1] = bytes32(uint256(uint160(address(this))));
        wallet.initialize(owners, address(validator), address(_fallback));
    }

    function _packHash(bytes32 hash) private view returns (bytes32) {
        uint256 _chainid;
        assembly {
            _chainid := chainid()
        }
        address account = msg.sender;
        return keccak256(abi.encode(hash, account, _chainid));
    }

    function _packSignature(address validatorAddress, bytes memory signature) private pure returns (bytes memory) {
        uint32 sigLen = uint32(signature.length);
        return abi.encodePacked(validatorAddress, sigLen, signature);
    }

    function testValidateUserOp() public {
        bytes32 userOpHash = 0x730c274949babbb86d1fe13fc1b52472e3ed76a83e3229792ac373fbd76ea105;
        bytes32 hash = _packHash(userOpHash).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(walletOwnerPrivateKey, hash);
        bytes memory _signature = abi.encodePacked(r, s, v);
        bytes memory signature = _packSignature(address(validator), _signature);

        address sender = address(wallet);
        uint256 nonce = 0;
        bytes memory initCode;
        bytes memory callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes memory paymasterAndData;
        {
            callGasLimit = 100000;
            verificationGasLimit = 200000;
            preVerificationGas = 100000;
            maxFeePerGas = 10 gwei;
            maxPriorityFeePerGas = 10 gwei;
        }
        UserOperation memory userOperation = UserOperation(
            sender,
            nonce,
            initCode,
            callData,
            callGasLimit,
            verificationGasLimit,
            preVerificationGas,
            maxFeePerGas,
            maxPriorityFeePerGas,
            paymasterAndData,
            signature
        );

        wallet.validateUserOp(userOperation, userOpHash, 0);
    }
}
