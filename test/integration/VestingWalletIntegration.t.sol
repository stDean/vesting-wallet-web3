// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {VestingWallet} from "src/VestingWallet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockToken} from "src/MockToken.sol";
import {DeployVestingWallet} from "script/DeployVestingWallet.s.sol";
import {CreateVestingSchedule, ReleaseToken} from "script/Interactions.s.sol";

/**
 * @title VestingWalletIntegrationTest
 * @author Dean
 * @notice Integration test suite for VestingWallet contract and associated scripts
 * @dev This contract tests the complete workflow of the VestingWallet system, including
 * deployment, vesting schedule creation, token release, and multiple beneficiary scenarios.
 * It verifies that all components work together correctly in an integrated environment.
 *
 * @custom:test-type Integration
 * @custom:test-covers Deployment, Schedule Creation, Token Release, Multi-Beneficiary Scenarios
 */
contract VestingWalletIntegrationTest is Test {
    DeployVestingWallet deployer;
    VestingWallet public vestingWallet;
    MockToken public token;
    address owner;

    /// @notice Test beneficiary address for vesting schedules
    address public beneficiary = makeAddr("beneficiary");

    /// @notice Random user address to test permissionless release functionality
    address public randomUser = makeAddr("randomUser");

    /// @notice Standard vesting amount used in tests (1000 ether)
    uint256 public constant VESTING_AMOUNT = 1000 ether;

    /// @notice Standard vesting duration used in tests (30 days)
    uint256 public constant VESTING_DURATION = 30 days;

    /// @notice Start time for vesting schedules (current time + 1 day)
    uint256 public startTime;

    /**
     * @notice Sets up the integration test environment
     * @dev Deploys contracts using the deployment script and prepares initial state
     * This function runs before each test case to ensure a clean testing environment
     */
    function setUp() external {
        deployer = new DeployVestingWallet();
        (vestingWallet, token) = deployer.run();
        owner = vestingWallet.getContractOwner();

        // Set up initial state
        startTime = block.timestamp + 1 days;

        // Mint tokens to owner for testing
        token.mint(owner, 1_000_000 ether);
    }

    /**
     * @notice Tests the complete workflow: deployment → schedule creation → token release
     * @dev Verifies the entire system works together correctly from deployment to token distribution
     * @custom:expectation All contracts should be deployed successfully
     * @custom:expectation Vesting schedule should be created with correct parameters
     * @custom:expectation Tokens should be released correctly after vesting period
     * @custom:expectation Contract state should be updated correctly at each step
     */
    function test_CompleteWorkflow() public {
        // Verify contracts are deployed
        assertTrue(address(vestingWallet) != address(0), "VestingWallet not deployed");
        assertTrue(address(token) != address(0), "MockToken not deployed");

        // Verify token is set correctly in VestingWallet
        assertEq(vestingWallet.getTokenAddress(), address(token), "Token address mismatch");

        // Verify ownership
        assertEq(vestingWallet.owner(), owner, "Ownership mismatch");

        // Create vesting schedule (simulating script execution)
        vm.startPrank(owner);
        token.approve(address(vestingWallet), VESTING_AMOUNT);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);
        vm.stopPrank();

        // Verify vesting schedule was created correctly
        (uint256 totalAmount, uint256 scheduleStartTime, uint256 duration, uint256 releasedAmount) =
            vestingWallet.s_vestingSchedules(beneficiary);

        assertEq(totalAmount, VESTING_AMOUNT, "Total amount mismatch");
        assertEq(scheduleStartTime, startTime, "Start time mismatch");
        assertEq(duration, VESTING_DURATION, "Duration mismatch");
        assertEq(releasedAmount, 0, "Initial released amount should be 0");

        // Verify tokens were transferred to vesting contract
        assertEq(token.balanceOf(address(vestingWallet)), VESTING_AMOUNT, "Vesting contract balance mismatch");

        // Warp to halfway through vesting period
        vm.warp(startTime + (VESTING_DURATION / 2));

        // Verify vested amount calculation
        uint256 vestedAmount = vestingWallet.vestedAmount(beneficiary);
        uint256 expectedVested = VESTING_AMOUNT / 2;
        assertEq(vestedAmount, expectedVested, "Vested amount calculation incorrect");

        // Verify releasable amount
        uint256 releasable = vestingWallet.releasableAmount(beneficiary);
        assertEq(releasable, expectedVested, "Releasable amount incorrect");

        // Release tokens (simulating script execution)
        uint256 beneficiaryBalanceBefore = token.balanceOf(beneficiary);
        vm.prank(randomUser); // Anyone can call release
        vestingWallet.release(beneficiary);

        // Verify tokens were transferred to beneficiary
        uint256 beneficiaryBalanceAfter = token.balanceOf(beneficiary);
        assertEq(
            beneficiaryBalanceAfter - beneficiaryBalanceBefore, expectedVested, "Tokens not transferred to beneficiary"
        );

        // Verify released amount was updated
        (,,, releasedAmount) = vestingWallet.s_vestingSchedules(beneficiary);
        assertEq(releasedAmount, expectedVested, "Released amount not updated");

        // Verify vesting contract balance decreased
        assertEq(
            token.balanceOf(address(vestingWallet)),
            VESTING_AMOUNT - expectedVested,
            "Vesting contract balance not updated"
        );
    }

    /**
     * @notice Tests deployment script functionality
     * @dev Verifies the deployment script correctly deploys and links contracts
     * @custom:expectation Script should deploy both contracts successfully
     * @custom:expectation Contracts should be properly linked
     * @custom:expectation Token address should be correctly set in VestingWallet
     */
    function test_DeploymentScript() public {
        // Run deployment script
        DeployVestingWallet deploymentScript = new DeployVestingWallet();
        (VestingWallet deployedVestingWallet, MockToken deployedToken) = deploymentScript.run();

        // Verify contracts were deployed
        assertTrue(address(deployedVestingWallet) != address(0), "VestingWallet not deployed by script");
        assertTrue(address(deployedToken) != address(0), "MockToken not deployed by script");

        // Verify token address is set correctly in VestingWallet
        assertEq(
            deployedVestingWallet.getTokenAddress(),
            address(deployedToken),
            "Token address not set correctly in VestingWallet"
        );
    }

    /**
     * @notice Tests multiple vesting schedules for different beneficiaries
     * @dev Verifies the system correctly handles multiple simultaneous vesting schedules
     * @custom:expectation Multiple schedules should be created successfully
     * @custom:expectation Each beneficiary should receive correct amounts
     * @custom:expectation Contract should maintain correct token balances
     */
    function test_MultipleBeneficiaries() public {
        address beneficiary2 = makeAddr("beneficiary2");
        uint256 amount2 = 500 ether;

        // Create first vesting schedule
        vm.startPrank(vestingWallet.owner());
        token.approve(address(vestingWallet), VESTING_AMOUNT + amount2);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);
        vestingWallet.createVestingSchedule(beneficiary2, amount2, startTime, VESTING_DURATION);
        vm.stopPrank();

        // Verify both schedules were created
        (uint256 totalAmount1,,,) = vestingWallet.s_vestingSchedules(beneficiary);
        (uint256 totalAmount2,,,) = vestingWallet.s_vestingSchedules(beneficiary2);

        assertEq(totalAmount1, VESTING_AMOUNT, "First vesting schedule incorrect");
        assertEq(totalAmount2, amount2, "Second vesting schedule incorrect");

        // Verify total tokens in vesting contract
        assertEq(
            token.balanceOf(address(vestingWallet)),
            VESTING_AMOUNT + amount2,
            "Total tokens in vesting contract incorrect"
        );

        // Warp to halfway through vesting period
        vm.warp(startTime + (VESTING_DURATION / 2));

        // Release tokens for both beneficiaries
        vm.prank(randomUser);
        vestingWallet.release(beneficiary);

        vm.prank(randomUser);
        vestingWallet.release(beneficiary2);

        // Verify both beneficiaries received correct amounts
        assertEq(token.balanceOf(beneficiary), VESTING_AMOUNT / 2, "First beneficiary received incorrect amount");
        assertEq(token.balanceOf(beneficiary2), amount2 / 2, "Second beneficiary received incorrect amount");
    }

    /**
     * @notice Tests contract token balance function
     * @dev Verifies the contractTokenBalance function returns correct values
     * @custom:expectation Should return correct balance of tokens in contract
     * @custom:expectation Should reflect balance changes after token releases
     */
    function test_ContractTokenBalance() public {
        // Create vesting schedule
        vm.startPrank(owner);
        token.approve(address(vestingWallet), VESTING_AMOUNT);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);
        vm.stopPrank();

        // Verify contract token balance
        uint256 contractBalance = vestingWallet.contractTokenBalance();
        assertEq(contractBalance, VESTING_AMOUNT, "Contract token balance incorrect");

        // Warp to halfway through vesting period and release tokens
        vm.warp(startTime + (VESTING_DURATION / 2));
        vm.prank(randomUser);
        vestingWallet.release(beneficiary);

        // Verify contract token balance after release
        contractBalance = vestingWallet.contractTokenBalance();
        assertEq(contractBalance, VESTING_AMOUNT / 2, "Contract token balance after release incorrect");
    }
}
