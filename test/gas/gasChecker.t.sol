// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BasicModularAccount} from "../../examples/BasicModularAccount.sol";

import {Execution} from "@source/interface/IStandardExecutor.sol";
import "@source/validators/BuildinEOAValidator.sol";
import {ReceiverHandler} from "./ReceiverHandler.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {DeployEntryPoint} from "../deployEntryPoint.sol";
import {SoulWalletFactory} from "./SoulWalletFactory.sol";
import {UserOperation} from "@account-abstraction/contracts/interfaces/UserOperation.sol";
import {TokenERC20} from "./TokenERC20.sol";

contract GasCheckerTest is Test {
    using MessageHashUtils for bytes32;

    IEntryPoint entryPoint;
    SoulWalletFactory walletFactory;
    BasicModularAccount walletImpl;

    BuildinEOAValidator validator;
    ReceiverHandler _fallback;

    TokenERC20 token;

    address public walletOwner1;
    uint256 public walletOwner1PrivateKey;
    address public walletOwner2;
    uint256 public walletOwner2PrivateKey;

    function setUp() public {
        entryPoint = new DeployEntryPoint().deploy();
        walletImpl = new BasicModularAccount(address(entryPoint));
        walletFactory = new SoulWalletFactory(address(walletImpl), address(entryPoint), address(this));

        validator = new BuildinEOAValidator();
        _fallback = new ReceiverHandler();

        (walletOwner1, walletOwner1PrivateKey) = makeAddrAndKey("owner1");

        (walletOwner2, walletOwner2PrivateKey) = makeAddrAndKey("owner2");

        token = new TokenERC20();
    }

    function test0() public view {
        console.log("+--------------------------------------------------------+");
        console.log("| * gas checker |              Item             |   gas  |");
        console.log("+--------------------------------------------------------+");
    }

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

    function _getRequiredPrefund(UserOperation memory mUserOp) internal pure returns (uint256 requiredPrefund) {
        unchecked {
            //when using a Paymaster, the verificationGasLimit is used also to as a limit for the postOp call.
            // our security model might call postOp eventually twice
            uint256 mul = mUserOp.paymasterAndData.length > 0 ? 3 : 1;
            uint256 requiredGas = mUserOp.callGasLimit + mUserOp.verificationGasLimit * mul + mUserOp.preVerificationGas;

            requiredPrefund = requiredGas * mUserOp.maxFeePerGas;
        }
    }

    function signUserOp(UserOperation memory userOperation) private view {
        bytes32 userOpHash = getUserOpHash(userOperation);
        bytes32 hash = _packHash(userOperation.sender, userOpHash).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(walletOwner1PrivateKey, hash);
        bytes memory _signature = _packSignature(address(validator), abi.encodePacked(r, s, v));
        userOperation.signature = _signature;
    }

    function deploy() private returns (uint256 gasCost, address sender) {
        bytes32 salt = 0;
        bytes memory initializer;
        {
            bytes32 owner = bytes32(uint256(uint160(walletOwner1)));
            address defaultValidator = address(validator);
            address defaultFallback = address(_fallback);
            initializer = abi.encodeWithSelector(
                BasicModularAccount.initialize.selector, owner, defaultValidator, defaultFallback
            );
        }
        sender = walletFactory.getWalletAddress(initializer, salt);
        //console.log("sender", sender);
        uint256 nonce = 0;
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
            callGasLimit = 0;
            verificationGasLimit = 1e6;
            preVerificationGas = 1e5;
            maxFeePerGas = 100 gwei;
            maxPriorityFeePerGas = 100 gwei;
            // function createWallet(bytes memory _initializer, bytes32 _salt)
            initCode = abi.encodePacked(
                walletFactory, abi.encodeWithSelector(SoulWalletFactory.createWallet.selector, initializer, salt)
            );
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

        signUserOp(userOperation);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = _getRequiredPrefund(userOperation);
        require(preFund < 0.2 ether, "preFund too high");
        vm.deal(sender, preFund);
        uint256 gasBefore = gasleft();
        entryPoint.handleOps(ops, payable(beneficiary));
        uint256 gasAfter = gasleft();
        gasCost = gasBefore - gasAfter;
    }

    function testDeploy() public {
        (uint256 gasCost,) = deploy();
        console.log("| * gas checker | Deploy Account:               |", gasCost, "|");
        console.log("+--------------------------------------------------------+");
    }

    function testETHTransfer() public {
        (, address sender) = deploy();

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
            // function execute(address target, uint256 value, bytes memory data)
            callGasLimit = 40000;
            callData = abi.encodeWithSelector(walletImpl.execute.selector, address(1), 1 ether, "");
            verificationGasLimit = 1e6;
            preVerificationGas = 1e5;
            maxFeePerGas = 100 gwei;
            maxPriorityFeePerGas = 100 gwei;
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

        signUserOp(userOperation);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = _getRequiredPrefund(userOperation);
        require(preFund < 0.2 ether, "preFund too high");
        vm.deal(sender, preFund + 1 ether);
        uint256 gasBefore = gasleft();
        entryPoint.handleOps(ops, payable(beneficiary));
        uint256 gasAfter = gasleft();
        console.log("address(1).balance,", address(1).balance);
        require(address(1).balance == 1 ether, "ETH transfer failed");
        uint256 gasCost = gasBefore - gasAfter;
        console.log("| * gas checker | ETH transfer:                 |", gasCost, "|");
        console.log("+--------------------------------------------------------+");
    }

    function testBatchETHTransfer() public {
        (, address sender) = deploy();

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
            //  function executeBatch(Execution[] calldata executions) external payable virtual override onlyEntryPoint {
            callGasLimit = 120000;
            Execution[] memory executions = new Execution[](3);
            executions[0] = Execution(address(1), 0.1 ether, "");
            executions[1] = Execution(address(2), 0.1 ether, "");
            executions[2] = Execution(address(3), 0.1 ether, "");
            callData = abi.encodeWithSelector(walletImpl.executeBatch.selector, executions);
            verificationGasLimit = 1e6;
            preVerificationGas = 1e5;
            maxFeePerGas = 100 gwei;
            maxPriorityFeePerGas = 100 gwei;
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

        signUserOp(userOperation);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = _getRequiredPrefund(userOperation);
        require(preFund < 0.2 ether, "preFund too high");
        vm.deal(sender, preFund + 1 ether);
        uint256 gasBefore = gasleft();
        entryPoint.handleOps(ops, payable(beneficiary));
        uint256 gasAfter = gasleft();
        console.log("address(1).balance,", address(1).balance);
        require(address(1).balance == 0.1 ether, "ETH transfer failed");
        uint256 gasCost = gasBefore - gasAfter;
        console.log("| * gas checker | ETH batch transfer:           | ", gasCost / 3, "|");
        console.log("+--------------------------------------------------------+");
    }

    function testERC20Transfer() public {
        (, address sender) = deploy();

        token.transfer(sender, 1 ether);

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
            // function transfer(address to, uint256 value)
            callGasLimit = 40000;
            bytes memory data = abi.encodeWithSelector(token.transfer.selector, address(1), 1 ether);
            callData = abi.encodeWithSelector(walletImpl.execute.selector, address(token), 0, data);
            verificationGasLimit = 1e6;
            preVerificationGas = 1e5;
            maxFeePerGas = 100 gwei;
            maxPriorityFeePerGas = 100 gwei;
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

        signUserOp(userOperation);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = _getRequiredPrefund(userOperation);
        require(preFund < 0.2 ether, "preFund too high");
        vm.deal(sender, preFund);
        require(token.balanceOf(address(1)) == 0 ether);
        uint256 gasBefore = gasleft();
        entryPoint.handleOps(ops, payable(beneficiary));
        uint256 gasAfter = gasleft();
        console.log("address(1).balance,", token.balanceOf(address(1)));
        require(token.balanceOf(address(1)) == 1 ether, "ERC20 transfer failed");
        uint256 gasCost = gasBefore - gasAfter;
        console.log("| * gas checker | ERC20 transfer:               | ", gasCost, "|");
        console.log("+--------------------------------------------------------+");
    }

    function testBatchERC20Transfer() public {
        (, address sender) = deploy();

        token.transfer(sender, 3 ether);

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
            // function execute(address target, uint256 value, bytes memory data)
            callGasLimit = 120000;
            Execution[] memory executions = new Execution[](3);
            executions[0] =
                Execution(address(token), 0, abi.encodeWithSelector(token.transfer.selector, address(1), 1 ether));
            executions[1] =
                Execution(address(token), 0, abi.encodeWithSelector(token.transfer.selector, address(2), 1 ether));
            executions[2] =
                Execution(address(token), 0, abi.encodeWithSelector(token.transfer.selector, address(3), 1 ether));
            callData = abi.encodeWithSelector(walletImpl.executeBatch.selector, executions);
            verificationGasLimit = 1e6;
            preVerificationGas = 1e5;
            maxFeePerGas = 100 gwei;
            maxPriorityFeePerGas = 100 gwei;
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

        signUserOp(userOperation);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOperation;
        (address beneficiary,) = makeAddrAndKey("beneficiary");
        uint256 preFund = _getRequiredPrefund(userOperation);
        require(preFund < 0.2 ether, "preFund too high");
        vm.deal(sender, preFund);
        require(token.balanceOf(address(1)) == 0 ether);
        require(token.balanceOf(address(2)) == 0 ether);
        require(token.balanceOf(address(3)) == 0 ether);
        uint256 gasBefore = gasleft();
        entryPoint.handleOps(ops, payable(beneficiary));
        uint256 gasAfter = gasleft();
        console.log("address(3).balance,", token.balanceOf(address(3)));
        require(token.balanceOf(address(1)) == 1 ether, "ERC20 transfer failed");
        require(token.balanceOf(address(2)) == 1 ether, "ERC20 transfer failed");
        require(token.balanceOf(address(3)) == 1 ether, "ERC20 transfer failed");
        uint256 gasCost = gasBefore - gasAfter;
        console.log("| * gas checker | ERC20 batch transfer:         | ", gasCost / 3, "|");
        console.log("+--------------------------------------------------------+");
    }
}
