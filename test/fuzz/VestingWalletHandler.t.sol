// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {VestingWallet} from "src/VestingWallet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockToken} from "src/MockToken.sol";

/**
 * @title VestingWalletHandler
 * @author Dean
 * @notice Handler contract for invariant testing of VestingWallet
 * @dev This contract provides a controlled interface for fuzz testing and invariant testing
 * of the VestingWallet contract. It manages test state and provides functions to interact
 * with the VestingWallet in a predictable manner for testing purposes.
 *
 * @custom:invariant Total vested should equal sum of all vesting schedule amounts
 * @custom:invariant Total released should match sum of all released amounts
 * @custom:invariant Contract token balance should equal total vested minus total released
 * @custom:invariant Vested amount should never exceed total amount for any beneficiary
 * @custom:invariant Released amount should never exceed vested amount for any beneficiary
 */
contract VestingWalletHandler is Test {
    /// @notice Instance of the VestingWallet contract being tested
    VestingWallet public vestingWallet;

    /// @notice Mock ERC20 token used for testing
    MockToken public token;

    /// @notice Address of the contract owner
    address public owner;

    /// @notice Array of all beneficiary addresses with active vesting schedules
    address[] public beneficiaries;

    /// @notice Mapping to track if an address has an active vesting schedule
    mapping(address => bool) public isBeneficiary;

    // Track expected state for invariant testing
    /// @notice Mapping of expected vested amounts for each beneficiary
    mapping(address => uint256) public expectedVested;

    /// @notice Mapping of expected released amounts for each beneficiary
    mapping(address => uint256) public expectedReleased;

    /// @notice Mapping of expected releasable amounts for each beneficiary
    mapping(address => uint256) public expectedReleasable;

    /// @notice Total amount of tokens vested across all schedules
    uint256 public totalVested;

    /// @notice Total amount of tokens released across all schedules
    uint256 public totalReleased;

    // Fuzz testing constants
    /// @notice Minimum vesting amount for fuzz testing (1 ether)
    uint256 public constant MIN_AMOUNT = 1 ether;

    /// @notice Maximum vesting amount for fuzz testing (1000 ether)
    uint256 public constant MAX_AMOUNT = 1000 ether;

    /// @notice Minimum vesting duration for fuzz testing (1 day)
    uint256 public constant MIN_DURATION = 1 days;

    /// @notice Maximum vesting duration for fuzz testing (365 days)
    uint256 public constant MAX_DURATION = 365 days;

    /**
     * @notice Initializes the handler with contract instances
     * @dev Sets up the handler with the VestingWallet, MockToken, and owner address
     * @param _vestingWallet The VestingWallet contract instance to test
     * @param _token The MockToken contract instance to use for testing
     * @param _owner The address of the contract owner
     */
    constructor(VestingWallet _vestingWallet, MockToken _token, address _owner) {
        vestingWallet = _vestingWallet;
        token = _token;
        owner = _owner;
    }

    /**
     * @notice Creates a vesting schedule with constrained parameters
     * @dev Uses bound() to constrain inputs to reasonable ranges for fuzz testing
     * @param beneficiary Address of the beneficiary for the vesting schedule
     * @param amount Amount of tokens to vest (will be constrained to MIN_AMOUNT-MAX_AMOUNT)
     * @param startTime Start time of the vesting schedule (will be constrained to current time to 365 days in future)
     * @param duration Duration of the vesting period (will be constrained to MIN_DURATION-MAX_DURATION)
     * @custom:invariant Should not create duplicate vesting schedules for the same beneficiary
     * @custom:invariant Should not create schedules if owner has insufficient token balance
     */
    function createVestingSchedule(address beneficiary, uint256 amount, uint256 startTime, uint256 duration) public {
        // Constrain inputs
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        duration = bound(duration, MIN_DURATION, MAX_DURATION);
        startTime = bound(startTime, block.timestamp, block.timestamp + 365 days);

        // Skip if beneficiary already has a schedule
        if (isBeneficiary[beneficiary]) return;

        // Skip if owner doesn't have enough tokens
        if (token.balanceOf(owner) < amount) return;

        vm.startPrank(owner);
        token.approve(address(vestingWallet), amount);
        vestingWallet.createVestingSchedule(beneficiary, amount, startTime, duration);
        vm.stopPrank();

        // Update state
        beneficiaries.push(beneficiary);
        isBeneficiary[beneficiary] = true;
        totalVested += amount;
    }

    /**
     * @notice Releases vested tokens for a beneficiary
     * @dev Can be called by anyone to release vested tokens
     * @param beneficiary Address of the beneficiary to release tokens for
     * @custom:invariant Should only release tokens for beneficiaries with active schedules
     * @custom:invariant Should only release tokens when releasable amount > 0
     * @custom:invariant Should update expected released amounts correctly
     */
    function release(address beneficiary) public {
        // Skip if not a beneficiary
        if (!isBeneficiary[beneficiary]) return;

        // Skip if no tokens to release
        if (vestingWallet.releasableAmount(beneficiary) == 0) return;

        // Record expected state before release
        uint256 releasable = vestingWallet.releasableAmount(beneficiary);
        expectedReleased[beneficiary] += releasable;
        totalReleased += releasable;

        // Anyone can call release
        vestingWallet.release(beneficiary);
    }

    /**
     * @notice Warps time to simulate passage of time
     * @dev Advances block.timestamp by a constrained amount and updates expected state
     * @param time Amount of time to warp forward (will be constrained to 0-10 years)
     * @custom:invariant Should update expected vested amounts correctly after time warp
     * @custom:invariant Should update expected releasable amounts correctly after time warp
     */
    function warp(uint256 time) public {
        // Constrain time to reasonable values
        time = bound(time, 0, 10 * 365 days);
        vm.warp(block.timestamp + time);

        // Update expected state after time warp
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            (uint256 totalAmount, uint256 startTime, uint256 duration,) = vestingWallet.s_vestingSchedules(beneficiary);

            if (block.timestamp < startTime) {
                expectedVested[beneficiary] = 0;
            } else if (block.timestamp >= startTime + duration) {
                expectedVested[beneficiary] = totalAmount;
            } else {
                uint256 timeElapsed = block.timestamp - startTime;
                expectedVested[beneficiary] = (totalAmount * timeElapsed) / duration;
            }

            expectedReleasable[beneficiary] = expectedVested[beneficiary] - expectedReleased[beneficiary];
        }
    }

    /**
     * @notice Returns the number of beneficiaries with active vesting schedules
     * @dev Helper function for invariant tests
     * @return count Number of active beneficiaries
     */
    function getBeneficiaryCount() public view returns (uint256) {
        return beneficiaries.length;
    }

    /**
     * @notice Returns the beneficiary address at a specific index
     * @dev Helper function for invariant tests
     * @param index Index of the beneficiary to retrieve
     * @return beneficiary Address of the beneficiary at the specified index
     */
    function getBeneficiary(uint256 index) public view returns (address) {
        return beneficiaries[index];
    }
}
