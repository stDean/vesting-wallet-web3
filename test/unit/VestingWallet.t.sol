// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {VestingWallet} from "src/VestingWallet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockToken} from "src/MockToken.sol";
import {DeployVestingWallet} from "script/DeployVestingWallet.s.sol";

/**
 * @title VestingWalletTest
 * @author Dean
 * @notice Test contract for VestingWallet functionality
 * @dev This contract contains tests for the VestingWallet smart contract
 * using Foundry's testing framework. It tests various scenarios including
 * contract initialization, vesting schedule creation, and token release functionality.
 */
contract VestingWalletTest is Test {
    /// @notice Instance of the VestingWallet contract under test
    VestingWallet vestingWallet;
    /// @notice Mock ERC20 token used for testing vesting functionality
    MockToken token;
    /// @notice Deployment script instance for setting up test environment
    DeployVestingWallet deployer;

    /// @notice Test address representing a beneficiary of the vesting schedule
    address public beneficiary = makeAddr("beneficiary");
    /// @notice Test address representing a random user (not owner or beneficiary)
    address public randomUser = makeAddr("randomUser");
    /// @notice Constant representing the amount of tokens to be vested in tests
    uint256 public constant VESTING_AMOUNT = 1000 ether;
    /// @notice Constant representing the duration of the vesting period in tests
    uint256 public constant VESTING_DURATION = 365 days;
    /// @notice Start time for the vesting schedule in tests
    uint256 public startTime;
    /// @notice Address of the contract owner
    address public owner;

    /**
     * @notice Sets up the test environment before each test
     * @dev Deploys contracts, mints tokens to owner, and sets up initial conditions
     * This function runs before each test case to ensure a clean state
     */
    function setUp() public {
        // Deploy contracts using the deployment script
        deployer = new DeployVestingWallet();
        (vestingWallet, token) = deployer.run();

        owner = vestingWallet.getContractOwner();

        // Mint initial tokens to the owner for testing
        token.mint(owner, 1_000_000 ether);

        // Start acting as the owner
        vm.startPrank(owner);

        // Approve the vesting wallet to spend the VESTING_AMOUNT from the owner
        token.approve(address(vestingWallet), 1_000_000 ether);
        // Transfer some tokens to a random user for certain test scenarios
        token.transfer(randomUser, 1000 ether);
        // Set vesting to start 1 day from now
        startTime = block.timestamp + 1 days;

        // Stop acting as the owner
        vm.stopPrank();
    }

    /**
     * @notice Tests that the constructor reverts when given a zero address for the token
     * @dev Verifies proper validation of constructor parameters
     * @custom:expectation Should revert with VestingWallet__ZeroTokenAddress error
     */
    function test_ConstructorShouldRevertIfTokenAddressIsAddress0() public {
        vm.expectRevert(VestingWallet.VestingWallet__ZeroTokenAddress.selector);
        new VestingWallet(address(0));
    }

    /**
     * @notice Tests that the constructor correctly initializes the token address
     * @dev Verifies that the token address stored in VestingWallet matches the deployed token
     * @custom:expectation The token address returned by getTokenAddress should match the deployed token address
     */
    function test_ConstructorShouldInitializeTokenCorrectly() public view {
        assertEq(address(vestingWallet.getTokenAddress()), address(token));
    }

    /**
     * @notice Tests that non-owners cannot create vesting schedules
     * @dev Ensures that only the contract owner can create vesting schedules
     * @custom:expectation Should revert with OwnableUnauthorizedAccount error when non-owner tries to create a vesting schedule
     */
    function test_ShouldRevertWhenNonOwnerTriesToCreateVestingSchedule() public {
        vm.startPrank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, randomUser));
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);

        vm.stopPrank();
    }

    /**
     * @notice Tests that duplicate vesting schedules cannot be created for the same beneficiary
     * @dev Ensures that a beneficiary cannot have more than one active vesting schedule
     * @custom:expectation Should revert with VestingWallet__VestingScheduleAlreadyExists when attempting to create a duplicate schedule
     */
    function test_CannotCreateDuplicateVestingSchedule() public {
        vm.startPrank(owner);

        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);

        vm.expectRevert(VestingWallet.VestingWallet__VestingScheduleAlreadyExists.selector);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);

        vm.stopPrank();
    }

    /**
     * @notice Tests that creating a vesting schedule fails when certain conditions are not met
     * @dev Validates input parameters for creating a vesting schedule
     * @custom:expectation Should revert with appropriate custom errors for each invalid condition
     */
    function test_CreatingVestingScheduleShouldFailWhenCertainConditionsAreNotMet() public {
        vm.startPrank(owner);

        // Zero beneficiary address
        vm.expectRevert(VestingWallet.VestingWallet__ZeroBeneficiaryAddress.selector);
        vestingWallet.createVestingSchedule(address(0), VESTING_AMOUNT, startTime, VESTING_DURATION);

        // Zero amount
        vm.expectRevert(VestingWallet.VestingWallet__ZeroAmount.selector);
        vestingWallet.createVestingSchedule(beneficiary, 0, startTime, VESTING_DURATION);

        // Zero duration
        vm.expectRevert(VestingWallet.VestingWallet__ZeroDuration.selector);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, 0);

        // Vesting schedule already exists
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);
        vm.expectRevert(VestingWallet.VestingWallet__VestingScheduleAlreadyExists.selector);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);

        vm.stopPrank();
    }

    /**
     * @notice Tests successful creation of a vesting schedule and proper event emission
     * @dev Verifies that a vesting schedule can be created successfully, emits the correct event,
     * and stores the correct parameters in the contract state
     * @custom:expectation Should emit VestingScheduleCreated event with correct parameters
     * @custom:expectation Should store correct vesting schedule details in contract state
     * @custom:expectation Should transfer tokens to the vesting contract
     */
    function test_ShouldSuccessfullyCreateVestingScheduleAndEmitEvent() public {
        vm.startPrank(owner);

        // Create vesting schedule
        vm.expectEmit(true, false, false, true);
        emit VestingWallet.VestingScheduleCreated(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);

        // Verify vesting schedule details
        (uint256 totalAmount, uint256 start, uint256 duration, uint256 releasedAmount) =
            vestingWallet.s_vestingSchedules(beneficiary);

        assertEq(totalAmount, VESTING_AMOUNT);
        assertEq(start, startTime);
        assertEq(duration, VESTING_DURATION);
        assertEq(releasedAmount, 0);
        assertEq(vestingWallet.contractTokenBalance(), VESTING_AMOUNT);

        vm.stopPrank();
    }

    /**
     * @notice Tests that token release reverts before vesting period starts
     * @dev Ensures that no tokens can be released before the vesting start time
     * @custom:expectation Should revert with VestingWallet__NoTokensToRelease when attempting to release before vesting start
     */
    function test_ReleaseShouldRevertBeforeVestingStart() public {
        vm.startPrank(owner);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);
        vm.stopPrank();

        vm.startPrank(beneficiary);
        vm.expectRevert(VestingWallet.VestingWallet__NoTokensToRelease.selector);
        vestingWallet.release(beneficiary);
        vm.stopPrank();
    }

    /**
     * @notice Tests partial token release during the vesting period
     * @dev Verifies that a beneficiary can release a portion of tokens during the vesting period
     * and that the correct amount is transferred and state is updated
     * @custom:expectation Should emit TokensReleased event with correct amount
     * @custom:expectation Should update releasedAmount correctly
     * @custom:expectation Should transfer correct token amount to beneficiary
     * @custom:expectation Should maintain correct token balance in vesting contract
     */
    function test_PartialReleaseToken() public {
        vm.startPrank(owner);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);
        vm.stopPrank();

        // Move time to halfway through the vesting period
        vm.warp(startTime + (VESTING_DURATION / 2));

        vm.startPrank(beneficiary);

        // Expect event emission on token release
        vm.expectEmit(true, false, false, true);
        emit VestingWallet.TokensReleased(beneficiary, VESTING_AMOUNT / 2);
        vestingWallet.release(beneficiary);

        // Verify released amount and remaining balance
        (,,, uint256 releasedAmount) = vestingWallet.s_vestingSchedules(beneficiary);
        assertEq(releasedAmount, VESTING_AMOUNT / 2);
        assertEq(token.balanceOf(beneficiary), VESTING_AMOUNT / 2);
        // assertEq(token.balanceOf(address(vestingWallet)), VESTING_AMOUNT / 2);
        assertEq(vestingWallet.contractTokenBalance(), VESTING_AMOUNT / 2);

        vm.stopPrank();
    }

    /**
     * @notice Tests full token release after vesting period completion
     * @dev Verifies that a beneficiary can release all tokens after the vesting period ends
     * and that the correct amount is transferred and state is updated
     * @custom:expectation Should emit TokensReleased event with full amount
     * @custom:expectation Should update releasedAmount to total amount
     * @custom:expectation Should transfer all tokens to beneficiary
     * @custom:expectation Should have zero token balance in vesting contract
     */
    function test_FullReleaseToken() public {
        vm.startPrank(owner);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);
        vm.stopPrank();

        // Move time to the end of the vesting period
        vm.warp(startTime + VESTING_DURATION + 1 days); // 365 days + 1 second

        vm.startPrank(beneficiary);

        // Expect event emission on full token release
        vm.expectEmit(true, false, false, true);
        emit VestingWallet.TokensReleased(beneficiary, VESTING_AMOUNT);
        vestingWallet.release(beneficiary);

        // Verify all tokens have been released
        (,,, uint256 releasedAmount) = vestingWallet.s_vestingSchedules(beneficiary);
        assertEq(releasedAmount, VESTING_AMOUNT);
        assertEq(token.balanceOf(beneficiary), VESTING_AMOUNT);
        assertEq(vestingWallet.contractTokenBalance(), 0);

        vm.stopPrank();
    }

    /**
     * @notice Tests that token release reverts when no vesting schedule exists
     * @dev Ensures that the release function reverts when called for a beneficiary without a vesting schedule
     * @custom:expectation Should revert with VestingWallet__NoVestingSchedule when no schedule exists
     */
    function test_ReleaseShouldRevertIfNoVestingScheduleExists() public {
        vm.startPrank(beneficiary);
        vm.expectRevert(VestingWallet.VestingWallet__NoVestingSchedule.selector);
        vestingWallet.release(beneficiary);
        vm.stopPrank();
    }

    /**
     * @notice Tests vested amount calculations at different points in time
     * @dev Verifies that the vestedAmount function returns correct values at various stages of the vesting period
     * @custom:expectation Should return 0 before vesting starts
     * @custom:expectation Should return correct proportional amount during vesting period
     * @custom:expectation Should return full amount after vesting period ends
     */
    function test_VestedCalculations() public {
        vm.startPrank(owner);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);
        vm.stopPrank();

        // Before vesting starts
        assertEq(vestingWallet.vestedAmount(beneficiary), 0);

        // At 25% of vesting period
        vm.warp(startTime + (VESTING_DURATION / 4));
        assertEq(vestingWallet.vestedAmount(beneficiary), VESTING_AMOUNT / 4);

        // At 50% of vesting period
        vm.warp(startTime + (VESTING_DURATION / 2));
        assertEq(vestingWallet.vestedAmount(beneficiary), VESTING_AMOUNT / 2);

        // After vesting period ends
        vm.warp(startTime + VESTING_DURATION + 1 days);
        assertEq(vestingWallet.vestedAmount(beneficiary), VESTING_AMOUNT);
    }

    /**
     * @notice Tests that releasableAmount returns 0 before vesting starts
     * @dev Verifies that no tokens are releasable before the vesting period begins
     * @custom:expectation Should return 0 when called before vesting start time
     */
    function test_ReleasableAmountReturnsZeroBeforeVestingStarts() public {
        vm.startPrank(owner);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);
        vm.stopPrank();

        // Check before vesting starts
        uint256 releasable = vestingWallet.releasableAmount(beneficiary);
        assertEq(releasable, 0);
    }

    /**
     * @notice Tests that releasableAmount returns correct amount during vesting period
     * @dev Verifies that releasableAmount calculates the correct proportion of vested but unreleased tokens
     * @custom:expectation Should return correct proportional amount during vesting period
     */
    function test_ReleasableAmountReturnsCorrectAmountDuringVesting() public {
        vm.startPrank(owner);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);
        vm.stopPrank();

        // Move to 25% through vesting period
        vm.warp(startTime + (VESTING_DURATION / 4));

        uint256 releasable = vestingWallet.releasableAmount(beneficiary);
        uint256 expectedAmount = VESTING_AMOUNT / 4;

        assertEq(releasable, expectedAmount);
    }

    /**
     * @notice Tests that releasableAmount returns 0 after all tokens have been released
     * @dev Verifies that no tokens are releasable after the full amount has been released
     * @custom:expectation Should return 0 after all tokens have been released
     */
    function test_ReleasableAmountReturnsZeroAfterFullRelease() public {
        vm.startPrank(owner);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, VESTING_DURATION);
        vm.stopPrank();

        // Move to end of vesting period
        vm.warp(startTime + VESTING_DURATION + 1 days);

        // Release all tokens
        vm.startPrank(beneficiary);
        vestingWallet.release(beneficiary);
        vm.stopPrank();

        // Check that no more tokens are releasable
        uint256 releasable = vestingWallet.releasableAmount(beneficiary);
        assertEq(releasable, 0);
    }
}
