// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";
import {ProxyFactory} from "../src/ProxyFactory.sol";

contract MultiSigWalletWithTimelockTest is Test {
    MultiSigWalletWithTimelock public implementation;
    ProxyFactory public factory;
    address public proxy;
    MultiSigWalletWithTimelock public wallet;
    address[] public signers;
    address public signer1 = address(0x1);
    address public signer2 = address(0x2);
    address public signer3 = address(0x3);
    address public recipient = address(0x4);

    function setUp() public {
        implementation = new MultiSigWalletWithTimelock();
        factory = new ProxyFactory(address(implementation));
        proxy = factory.createProxy();
        wallet = MultiSigWalletWithTimelock(payable(proxy));

        signers = [signer1, signer2, signer3];
        vm.deal(signer1, 10 ether);
        vm.deal(signer2, 10 ether);
        vm.deal(signer3, 10 ether);

        vm.deal(address(wallet), 50 ether);
    }

    /**
     * @notice Test submit transaction, a public state-modifying contract function.
     * @custom:signature testSubmitTransaction()
     * @custom:selector 0x1f0af8f0
     */
    function testSubmitTransaction() public {
        uint value = 1 ether;
        uint requiredSignatures = 2;
        uint _executeAfter = block.timestamp + 1 days;

        vm.prank(signer1);
        wallet.submitETHTransaction{value: value}(
            recipient,
            signers,
            requiredSignatures,
            _executeAfter
        );

        (
            address to,
            uint txValue,
            ,
            bool executed,
            uint reqSignatures,
            uint executeAfter
        ) = wallet.transactions(0);

        assertEq(to, recipient);
        assertEq(txValue, value);
        assertEq(executed, false);
        assertEq(reqSignatures, requiredSignatures);
        assertEq(executeAfter, _executeAfter);
    }

    function testApproveTransaction() public {
        uint value = 1 ether;
        uint requiredSignatures = 2;
        uint timelockDuration = 1 days;

        vm.prank(signer1);
        wallet.submitETHTransaction{value: value}(
            recipient,
            signers,
            requiredSignatures,
            timelockDuration
        );

        vm.prank(signer1);
        wallet.approveTransaction(0);

        (, , uint approvals, , , ) = wallet.transactions(0);
        assertEq(approvals, 1);
    }

    function testExecuteTransaction() public {
        uint value = 1 ether;
        uint requiredSignatures = 2;
        uint timelockDuration = 1 days;

        vm.prank(signer1);
        wallet.submitETHTransaction{value: value}(
            recipient,
            signers,
            requiredSignatures,
            timelockDuration
        );

        vm.prank(signer1);
        wallet.approveTransaction(0);
        vm.prank(signer2);
        wallet.approveTransaction(0);

        vm.warp(block.timestamp + timelockDuration);

        vm.prank(signer1);
        wallet.executeETHTransaction(0);

        (, , , bool executed, , ) = wallet.transactions(0);
        assertEq(executed, true);
        assertEq(recipient.balance, value);
    }

    function testFailExecuteTransactionWithoutEnoughApprovals() public {
        uint value = 1 ether;
        uint requiredSignatures = 2;
        uint timelockDuration = 1 days;

        vm.prank(signer1);
        wallet.submitETHTransaction{value: value}(
            recipient,
            signers,
            requiredSignatures,
            timelockDuration
        );

        vm.prank(signer1);
        wallet.approveTransaction(0);

        vm.warp(block.timestamp + timelockDuration);

        vm.prank(signer1);
        wallet.executeETHTransaction(0); // Should fail due to insufficient approvals
    }

    function testFailExecuteTransactionBeforeTimelock() public {
        uint value = 1 ether;
        uint requiredSignatures = 2;
        uint timelockDuration = 1 days;

        vm.prank(signer1);
        wallet.submitETHTransaction{value: value}(
            recipient,
            signers,
            requiredSignatures,
            timelockDuration
        );

        vm.prank(signer1);
        wallet.approveTransaction(0);
        vm.prank(signer2);
        wallet.approveTransaction(0);

        vm.prank(signer1);
        wallet.executeETHTransaction(0); // Should fail due to timelock not passed
    }
}
