// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {PureWallet} from "./pureWallet.sol";

import {Execution} from "@source/interface/IStandardExecutor.sol";
import "@source/validators/BuildinEOAValidator.sol";
import {ReceiverHandler} from "./ReceiverHandler.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {DeployEntryPoint} from "../deployEntryPoint.sol";
import {SoulWalletFactory} from "./SoulWalletFactory.sol";
import {UserOperation} from "@account-abstraction/contracts/interfaces/UserOperation.sol";

contract GasCheckerTest is Test {
    using MessageHashUtils for bytes32;

    IEntryPoint entryPoint;
    SoulWalletFactory walletFactory;
    PureWallet walletImpl;

    BuildinEOAValidator validator;
    ReceiverHandler _fallback;

    address public walletOwner1;
    uint256 public walletOwner1PrivateKey;
    address public walletOwner2;
    uint256 public walletOwner2PrivateKey;

    function setUp() public {
        entryPoint = new DeployEntryPoint().deploy();
        walletImpl = new PureWallet(address(entryPoint));
        walletFactory = new SoulWalletFactory(address(walletImpl), address(entryPoint), address(this));

        validator = new BuildinEOAValidator();
        _fallback = new ReceiverHandler();

        (walletOwner1, walletOwner1PrivateKey) = makeAddrAndKey("owner1");

        (walletOwner2, walletOwner2PrivateKey) = makeAddrAndKey("owner2");
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
            bytes32[] memory owners = new bytes32[](1);
            owners[0] = bytes32(uint256(uint160(walletOwner1)));
            //owners[1] = bytes32(uint256(uint160(walletOwner2)));
            address defaultValidator = address(validator);
            address defaultFallback = address(_fallback);
            initializer =
                abi.encodeWithSelector(PureWallet.initialize.selector, owners, defaultValidator, defaultFallback);
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

    function testETHTransferWithData() public {
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
            bytes memory data =
                hex"ff75322f410fabc35708af2dbaa27a1781c5f9dd7ad6b87eb760bff7eed68004ff75322f410fabc35708af2dbaa27a1781c5";
            callData = abi.encodeWithSelector(walletImpl.execute.selector, address(1), 1 ether, data);
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
        console.log("| * gas checker | ETH transfer with data:       |", gasCost, "|");
        console.log("+--------------------------------------------------------+");
    }

    function testbatchETHTransfer() public {
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
        console.log("| * gas checker | batch ETH transfer:           |", gasCost, "|");
        console.log("+--------------------------------------------------------+");
    }

    function testbatchETHTransferWithData() public {
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
            bytes memory data =
                hex"ff75322f410fabc35708af2dbaa27a1781c5f9dd7ad6b87eb760bff7eed68004ff75322f410fabc35708af2dbaa27a1781c5";
            executions[0] = Execution(address(1), 0.1 ether, data);
            executions[1] = Execution(address(2), 0.1 ether, data);
            executions[2] = Execution(address(3), 0.1 ether, data);
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
        console.log("| * gas checker | batch ETH transfer with data: |", gasCost, "|");
        console.log("+--------------------------------------------------------+");
    }
}
