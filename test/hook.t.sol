// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {IModuleManager} from "@source/interface/IModuleManager.sol";
import {IOwnerManager} from "@source/interface/IOwnerManager.sol";
import {BasicModularAccount} from "../examples/BasicModularAccount.sol";
import {Execution} from "@source/interface/IStandardExecutor.sol";
import "@source/validators/EOAValidator.sol";
import {ReceiverHandler} from "./dev/ReceiverHandler.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {DeployEntryPoint} from "./dev/deployEntryPoint.sol";
import {SoulWalletFactory} from "./dev/SoulWalletFactory.sol";
import {UserOperation} from "@account-abstraction/contracts/interfaces/UserOperation.sol";
import {TokenERC20} from "./dev/TokenERC20.sol";
import {DemoHook} from "./dev/demoHook.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "@source/utils/Constants.sol";

contract HookTest is Test {
    using MessageHashUtils for bytes32;

    IEntryPoint entryPoint;

    SoulWalletFactory walletFactory;
    BasicModularAccount walletImpl;

    EOAValidator validator;
    ReceiverHandler _fallback;

    TokenERC20 token;
    DemoHook demoHook;

    address public walletOwner;
    uint256 public walletOwnerPrivateKey;

    BasicModularAccount wallet;

    function setUp() public {
        entryPoint = new DeployEntryPoint().deploy();
        walletImpl = new BasicModularAccount(address(entryPoint));
        walletFactory = new SoulWalletFactory(address(walletImpl), address(entryPoint), address(this));
        validator = new EOAValidator();
        _fallback = new ReceiverHandler();
        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("owner1");
        token = new TokenERC20();
        demoHook = new DemoHook();

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

    function getUserOpHash(UserOperation memory userOp) private view returns (bytes32) {
        return entryPoint.getUserOpHash(userOp);
    }

    function signUserOp(UserOperation memory userOperation) private view returns (bytes32 userOpHash) {
        userOpHash = getUserOpHash(userOperation);
        bytes32 hash = _packHash(userOperation.sender, userOpHash).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(walletOwnerPrivateKey, hash);
        bytes memory _signature = _packSignature(address(validator), abi.encodePacked(r, s, v));
        userOperation.signature = _signature;
    }

    function test_Hook() public {
        vm.deal(address(wallet), 1000 ether);
        bytes memory hookData = hex"aabbcc";
        bytes memory hookAndData = abi.encodePacked(address(demoHook), hookData);

        vm.startPrank(address(wallet));
        vm.expectEmit(true, true, true, true); //   (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
        emit InitCalled(hookData);
        wallet.installHook(hookAndData, 3);
        assertTrue(wallet.isInstalledHook(address(demoHook)));
        vm.stopPrank();

        (address[] memory preIsValidSignatureHooks, address[] memory preUserOpValidationHooks) = wallet.listHook();
        assertEq(preIsValidSignatureHooks.length, 1);
        assertEq(preUserOpValidationHooks.length, 1);
        assertEq(preIsValidSignatureHooks[0], address(demoHook));
        assertEq(preUserOpValidationHooks[0], address(demoHook));

        uint256 nonce = 1;
        bytes memory initCode;
        bytes memory callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes memory paymasterAndData;
        bytes memory signature;
        {
            callGasLimit = 200000;
            // function execute(address target, uint256 value, bytes calldata data) external payable;
            callData = abi.encodeWithSelector(walletImpl.execute.selector, address(10), 1 ether, "");
            verificationGasLimit = 1e6;
            preVerificationGas = 1e5;
            maxFeePerGas = 100 gwei;
            maxPriorityFeePerGas = 100 gwei;
        }
        UserOperation memory userOperation = UserOperation(
            address(wallet),
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

        // function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        vm.startPrank(address(entryPoint));

        bytes32 userOpHash = signUserOp(userOperation);
        assertEq(wallet.validateUserOp(userOperation, userOpHash, 1), SIG_VALIDATION_SUCCESS);

        userOperation.callData = abi.encodeWithSelector(walletImpl.execute.selector, address(10), 2 ether, "");
        userOpHash = signUserOp(userOperation);
        assertEq(wallet.validateUserOp(userOperation, userOpHash, 1), SIG_VALIDATION_FAILED);

        vm.stopPrank();

        vm.expectRevert(CALLER_MUST_BE_SELF_OR_MODULE.selector);
        wallet.uninstallHook(address(demoHook));

        vm.startPrank(address(wallet));
        vm.expectEmit(true, true, true, true); //   (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
        emit DeInitCalled();
        wallet.uninstallHook(address(demoHook));
        (address[] memory _preIsValidSignatureHooks, address[] memory _preUserOpValidationHooks) = wallet.listHook();
        assertEq(_preIsValidSignatureHooks.length, 0);
        assertEq(_preUserOpValidationHooks.length, 0);
        vm.stopPrank();
    }
}
