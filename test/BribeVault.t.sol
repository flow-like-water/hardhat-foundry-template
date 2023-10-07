// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/BribeVault.sol";
import "../src/RewardDistributor.sol";

contract BribeVaultTest is Test {
    BribeVault bribeVault;
    RewardDistributor rewardDistributor;
    address admin = address(0x99);
    address depositor = address(0x88);
    address feeRecipient = address(0x77);
    address distributor = address(0x66);
    address briber = address(0x55);

    uint256 initialFee = 30000; // 0.4%
    uint256 initialFeeMax = 50000; // 0.5%

    function setUp() public {
        // Initialize the RewardDistributor contract
        rewardDistributor = new RewardDistributor();

        // Initialize the BribeVault contract
        bribeVault = new BribeVault(
            initialFee,
            initialFeeMax,
            feeRecipient,
            address(rewardDistributor)
        );
    }

    function test_grantAndRevokeDepositorRole() public {
        // Grant depositor role to the depositor address
        bribeVault.grantDepositorRole(depositor);

        // Check to see the role was granted successfully
        assertTrue(bribeVault.hasRole(keccak256("DEPOSITOR_ROLE"), depositor));

        // Revoke the role from the 0x0 address - should revert
        vm.expectRevert();
        bribeVault.revokeDepositorRole(address(0));

        // Revoke the role from the depositor
        bribeVault.revokeDepositorRole(depositor);

        // Assert that the depositor role was revoked
        assertFalse(bribeVault.hasRole(keccak256("DEPOSITOR_ROLE"), depositor));
    }

    function test_setFee() public {
        // Set the fee above FEE_MAX
        vm.expectRevert();
        bribeVault.setFee(60000); // Exceeds FEE_MAX

        // Set the fee to 3%
        bribeVault.setFee(30000);

        // Assert that the fee was updated in the contract
        assertEq(bribeVault.fee(), 30000);
    }

    function test_setFeeRecipient() public {
        // Set the feeRecipient to the 0x0 address - should revert
        vm.expectRevert();
        bribeVault.setFeeRecipient(address(0)); // zero address

        // Set the feeRecipient
        bribeVault.setFeeRecipient(feeRecipient);

        // Assert that the feeRecipient was updated in the contract
        assertEq(bribeVault.feeRecipient(), feeRecipient);
    }

    function test_setDistributor() public {
        // Set the feeRecipient to the 0x0 address - should revert
        vm.expectRevert();
        bribeVault.setDistributor(address(0)); // zero address

        // Set the setDistributor
        bribeVault.setDistributor(distributor);

        // Assert that the distributor address was updated in the contract
        assertEq(bribeVault.distributor(), distributor);
    }

    function test_generateBribeVaultIdentifier() public {
        bytes32 id = bribeVault.generateBribeVaultIdentifier(
            address(1),
            keccak256("proposal"),
            uint256(123456),
            address(2)
        );
        bytes32 expectedId = keccak256(
            abi.encodePacked(
                address(1),
                keccak256("proposal"),
                uint256(123456),
                address(2)
            )
        );
        assertEq(id, expectedId);
    }

    function test_generateRewardIdentifier() public {
        bytes32 id = bribeVault.generateRewardIdentifier(
            address(1),
            address(2),
            uint256(123456)
        );
        bytes32 expectedId = keccak256(
            abi.encodePacked(address(1), uint256(123456), address(2))
        );
        assertEq(id, expectedId);
    }

    function test_getBribe() public {
        // Mock data for the bribe
        address mockToken = address(0x1234); // Replace with actual mock token address
        uint256 mockAmount = 1000;
        bytes32 mockProposal = keccak256("mockProposal");
        uint256 mockDeadline = block.timestamp + 7 days; // Assuming a week-long proposal for example
        uint256 mockPeriodDuration = 1 days; // Assuming daily periods
        uint256 mockPeriods = 7; // 7 days of bribe
        uint256 mockMaxTokensPerVote = 10;
        uint256 mockPermitDeadline = block.timestamp + 6 days;
        bytes memory mockSignature = ""; // Empty for this test, but could use a valid one if testing permit2

        // Grant the test contract the depositor role so it can deposit a bribe
        bribeVault.grantDepositorRole(depositor);

        // Deposit the bribe
        Common.DepositBribeParams memory params = Common.DepositBribeParams({
            token: mockToken,
            amount: mockAmount,
            briber: address(briber),
            proposal: mockProposal,
            proposalDeadline: mockDeadline,
            periods: mockPeriods,
            periodDuration: mockPeriodDuration,
            maxTokensPerVote: mockMaxTokensPerVote,
            permitDeadline: mockPermitDeadline,
            signature: mockSignature
        });
        bribeVault.depositBribe(params);

        // Generate the bribe identifier for the first period
        bytes32 bribeIdentifier = bribeVault.generateBribeVaultIdentifier(
            address(briber),
            mockProposal,
            mockDeadline,
            mockToken
        );

        // Fetch and validate the bribe details
        (address token, uint256 amount) = bribeVault.getBribe(bribeIdentifier);

        assertEq(token, mockToken); // Validate token
        assertEq(amount, mockAmount); // Validate amount, adjust as per your distribution logic
    }

    /*function test_getBribe() public {
        // You will need to first deposit a bribe to test this function.
        // ... code to deposit bribe
        //bytes32 bribeIdentifier =  the calculated bribe identifier;
        (address token, uint256 amount) = bribeVault.getBribe(bribeIdentifier);
        vm.assertEq(token, expected token address);
        vm.assertEq(amount, expected amount);
    }

    function test_getBribeIdentifiersByRewardIdentifier() public {
        // You will need to first deposit multiple bribes associated with the same reward identifier
        // ... code to deposit bribes
        bytes32 rewardIdentifier = /* the calculated reward identifier;
        bytes32[] memory bribeIdentifiers = bribeVault.getBribeIdentifiersByRewardIdentifier(rewardIdentifier);
        // Add your own logic to check that bribeIdentifiers contains the expected elements
    }

    function test_setRewardForwarding() public {
        bribeVault.setRewardForwarding(address(0x123));
        // You'll need to check the state of the contract to see if the forwarding was correctly set.
        // If your contract has a public/external getter for the rewardForwarding mapping, you can use that here.
    }

    function test_emergencyWithdraw() public {
        vm.expectRevert(); // Assumes that the test case will run as a non-admin
        bribeVault.emergencyWithdraw(address(0x1), 100);
    }

    function test_transferBribes() public {
        // First, you'd probably have to simulate bribes being deposited to generate rewardIdentifiers
        bytes32[] memory rewardIdentifiers = /* array of rewardIdentifiers;
        vm.expectRevert(); // Assumes that the test case will run as a non-admin
        bribeVault.transferBribes(rewardIdentifiers);
    }*/
}
