// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../src/Surge.sol";
import "../src/FiscOwnable.sol";

contract TestFiscOwnable is FiscOwnable {
    constructor(address initialFisc) FiscOwnable(initialFisc) {}
}

contract SurgeTest is Test {
    Surge surge;
    TestFiscOwnable fisc;
    address owner = address(0x99);
    address fiscAddress = address(0x77);
    address user = address(0x2);
    uint256 mintLock = block.timestamp + 1 days;
    uint256 mintStart = block.timestamp + 2 days;
    uint256 mintEnd = block.timestamp + 3 days;

    function setUp() public {
        fisc = new TestFiscOwnable(fiscAddress);

        // Create the Surge contract instance.
        surge = new Surge(
            mintLock,
            mintStart,
            mintEnd,
            address(fiscAddress)
        );

        // Transfer ownership to the 0x99 address.
        surge.transferOwnership(owner);
    }

    // addMint() function tests
    function test_addMint_OnlyOwnerCanAddMint() public {
        vm.expectRevert();
        vm.prank(user);
        surge.addMint(user, 500);
    }

    function test_addMint_AddMintBeforemintLock() public {
        vm.warp(mintLock - 1);
        vm.prank(owner);
        surge.addMint(user, 500);
        assertEq(surge.mintOf(user), 500);
    }

    function test_addMint_AddMintAftermintLock() public {
        vm.warp(mintLock + 1);
        vm.prank(owner);
        vm.expectRevert();
        surge.addMint(user, 500);
    }

    function test_addMint_AddZeroAmount() public {
        vm.warp(mintLock - 1);
        vm.prank(owner);
        vm.expectRevert();
        surge.addMint(user, 0);
    }

    function test_addMint_AddMintToFiscAddress() public {
        vm.warp(mintLock - 1);
        address fiscAddressLower = address(uint160(surge.Fisc()));
        emit log_named_address("surge.fisc", surge.Fisc());
        vm.prank(owner);
        vm.expectRevert();
        surge.addMint(fiscAddressLower, 500);
    }

    function test_addMint_SubtractMintAmountFromFisc() public {
        vm.warp(mintLock - 1);
        uint256 initialAmount = surge.mintOf(surge.Fisc());
        vm.prank(owner);
        surge.addMint(user, 500);
        assertEq(surge.mintOf(surge.Fisc()), initialAmount - 500);
    }

    // setMint() function tests
    function test_setMint_OnlyOwnerCanSetMint() public {
        vm.expectRevert();
        vm.prank(user);
        surge.setMint(user, 500);
    }

    function test_setMint_SetMintBeforemintLock() public {
        vm.warp(mintLock - 1);
        vm.prank(owner);
        surge.setMint(user, 500);
        assertEq(surge.mintOf(user), 500);
    }

    function test_setMint_SetMintAftermintLock() public {
        vm.warp(mintLock + 1);
        vm.prank(owner);
        vm.expectRevert();
        surge.setMint(user, 500);
    }

    function test_setMint_SetZeroAmount() public {
        vm.warp(mintLock - 1);
        vm.prank(owner);
        surge.setMint(user, 1000);
        assertEq(surge.mintOf(user), 1000);
        vm.prank(owner);
        surge.setMint(user, 0);
        assertEq(surge.mintOf(user), 0);
    }

    function test_setMint_SetMintToFiscAddress() public {
        vm.warp(mintLock - 1);
        address fiscAddressLower = address(uint160(surge.Fisc()));
        emit log_named_address("surge.fisc", surge.Fisc());
        vm.prank(owner);
        vm.expectRevert();
        surge.setMint(fiscAddressLower, 500);
    }

    function test_setMint_SubtractMintAmountFromFisc() public {
        vm.warp(mintLock - 1);
        uint256 initialAmount = surge.mintOf(surge.Fisc());
        vm.prank(owner);
        surge.setMint(user, 500);
        assertEq(surge.mintOf(surge.Fisc()), initialAmount - 500);
    }

    // mint() function tests
    function test_MintableAmountForTargetAccount() public {
        vm.warp(mintLock - 1);
        uint256 initialAmount = surge.mintOf(user);
        vm.prank(owner);
        surge.addMint(user, 500);
        assertEq(surge.mintOf(user), initialAmount + 500);
    }

    function test_CanMintSuccessfully() public {
        vm.warp(mintLock - 1);
        vm.prank(owner);
        surge.addMint(owner, 1000);
        vm.warp(mintStart + 1);
        vm.prank(owner);
        bool result = surge.mint();
        assertTrue(result);
        assertEq(surge.balanceOf(owner), 1000);
    }

    function test_CantMintBeforeStart() public {
        vm.expectRevert();
        vm.warp(mintStart - 1);
        vm.prank(owner);
        surge.mint();
    }

    function test_CantMintAfterExpiration() public {
        vm.warp(mintEnd + 1);
        vm.prank(owner);
        vm.expectRevert();
        surge.mint();
    }

    function test_CantMintZeroTokens() public {
        vm.warp(mintLock - 1);
        vm.prank(owner);
        vm.expectRevert();
        surge.addMint(owner, 0);
    }
}
