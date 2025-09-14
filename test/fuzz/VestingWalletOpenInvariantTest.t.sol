// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {VestingWallet} from "src/VestingWallet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockToken} from "src/MockToken.sol";
import {DeployVestingWallet} from "script/DeployVestingWallet.s.sol";

/**
 * @title VestingWalletOpenInvariantTest
 * @author Dean
 * @notice Open invariant test suite for VestingWallet contract
 * @dev This contract tests fundamental properties and invariants of the VestingWallet contract
 * using Foundry's testing framework with invariant testing support. It verifies that critical
 * security properties and expected behaviors remain true under various conditions.
 *
 * @custom:invariant Anyone can release vested tokens (permissionless release)
 * @custom:invariant Only owner can create vesting schedules (access control)
 * @custom:invariant Token address is immutable after deployment
 * @custom:invariant Vesting schedules cannot be modified after creation
 */
contract VestingWalletOpenInvariantTest is StdInvariant, Test {
    /// @notice Instance of the VestingWallet contract under test
    VestingWallet vestingWallet;

    /// @notice Mock ERC20 token used for testing
    MockToken token;

    /// @notice Deployment script instance
    DeployVestingWallet deployer;

    /// @notice Address of the contract owner
    address owner;

    /// @notice Constant vesting amount used in tests (1000 ether)
    uint256 constant VESTING_AMOUNT = 1000 ether;

    /// @notice Constant vesting duration used in tests (365 days)
    uint256 public constant VESTING_DURATION = 365 days;

    /// @notice Start time for vesting schedules (current time + 1 day)
    uint256 public START_TIME = block.timestamp + 1 days;

    /// @notice Beneficiary address for test vesting schedules
    address public beneficiary = makeAddr("beneficiary");

    /// @notice Random caller address used to test permissionless functions
    address randomCaller = makeAddr("randomCaller");

    /**
     * @notice Sets up the test environment before each test
     * @dev Deploys contracts, mints tokens to owner, and approves spending
     * This function runs before each test case to ensure a clean state
     */
    function setUp() public {
        deployer = new DeployVestingWallet();
        (vestingWallet, token) = deployer.run();

        owner = vestingWallet.getContractOwner();
        // Mint tokens to owner
        token.mint(owner, 1_000_000 ether);

        vm.prank(owner);
        token.approve(address(vestingWallet), 1_000_000 ether);
    }

    /**
     * @notice Tests that anyone can release vested tokens to beneficiaries
     * @dev Verifies the permissionless nature of the release function
     * @custom:expectation Random caller should be able to release vested tokens
     * @custom:expectation Released amount should equal the vested amount after time warp
     */
    function testOpenInvariant_anyoneCanRelease() public {
        vm.prank(owner);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, START_TIME, VESTING_DURATION);

        // Warp to halfway through vesting period
        vm.warp(START_TIME + VESTING_DURATION / 2);

        // Anyone should be able to call release
        vm.prank(randomCaller);
        vestingWallet.release(makeAddr("beneficiary"));

        (,,, uint256 releasedAmount) = vestingWallet.s_vestingSchedules(beneficiary);
        assertEq(releasedAmount, VESTING_AMOUNT / 2);
    }

    /**
     * @notice Tests that only the owner can create vesting schedules
     * @dev Verifies the access control mechanism for schedule creation
     * @custom:expectation Non-owner should revert with OwnableUnauthorizedAccount error
     */
    function testOpenInvariant_onlyOwnerCanCreateSchedule() public {
        vm.prank(randomCaller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, randomCaller));
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, START_TIME, VESTING_DURATION);
    }

    /**
     * @notice Tests that the token address is immutable after deployment
     * @dev Verifies that the token address cannot be changed once set
     * @custom:expectation Token address should remain constant between calls
     */
    function testOpenInvariant_tokenAddressImmutable() public view {
        address initialTokenAddress = vestingWallet.getTokenAddress();

        assertEq(vestingWallet.getTokenAddress(), initialTokenAddress);
    }

    /**
     * @notice Tests that vesting schedules cannot be modified after creation
     * @dev Verifies the immutability of existing vesting schedules
     * @custom:expectation Creating a duplicate schedule should revert
     * @custom:expectation Original schedule parameters should remain unchanged
     */
    function testOpenInvariant_scheduleImmutable() public {
        vm.startPrank(owner);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, START_TIME, VESTING_DURATION);
        vm.stopPrank();

        // Try to create another schedule for the same beneficiary
        vm.startPrank(owner);
        vm.expectRevert(VestingWallet.VestingWallet__VestingScheduleAlreadyExists.selector);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, START_TIME, VESTING_DURATION);
        vm.stopPrank();

        // Verify the original schedule is unchanged
        (uint256 totalAmount, uint256 start, uint256 vestDuration, uint256 releasedAmount) =
            vestingWallet.s_vestingSchedules(beneficiary);

        assertEq(totalAmount, VESTING_AMOUNT);
        assertEq(start, START_TIME);
        assertEq(vestDuration, VESTING_DURATION);
        assertEq(releasedAmount, 0);
    }
}
