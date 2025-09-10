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
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, 30 days);

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
        vestingWallet.createVestingSchedule(address(0), VESTING_AMOUNT, startTime, 30 days);

        // Zero amount
        vm.expectRevert(VestingWallet.VestingWallet__ZeroAmount.selector);
        vestingWallet.createVestingSchedule(beneficiary, 0, startTime, 30 days);

        // Zero duration
        vm.expectRevert(VestingWallet.VestingWallet__ZeroDuration.selector);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, 0);

        // Vesting schedule already exists
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, 30 days);
        vm.expectRevert(VestingWallet.VestingWallet__VestingScheduleAlreadyExists.selector);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, 30 days);

        vm.stopPrank();
    }

    function test_ShouldSuccessfullyCreateVestingScheduleAndEmitEvent() public {
        vm.startPrank(owner);

        // Create vesting schedule
        vm.expectEmit(true, false, false, true);
        emit VestingWallet.VestingScheduleCreated(beneficiary, VESTING_AMOUNT, startTime, 30 days);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, startTime, 30 days);

        // Verify vesting schedule details
        (uint256 totalAmount, uint256 start, uint256 duration, uint256 releasedAmount) =
            vestingWallet.s_vestingSchedules(beneficiary);

        assertEq(totalAmount, VESTING_AMOUNT);
        assertEq(start, startTime);
        assertEq(duration, 30 days);
        assertEq(releasedAmount, 0);
        assertEq(token.balanceOf(address(vestingWallet)), VESTING_AMOUNT);

        vm.stopPrank();
    }
}
