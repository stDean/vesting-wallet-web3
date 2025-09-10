// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {VestingWallet} from "src/VestingWallet.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {MockToken} from "src/MockToken.sol";

/**
 * @title CreateVestingSchedule
 * @author Your Name
 * @notice Script to create a vesting schedule for a beneficiary
 * @dev This script creates a vesting schedule with a configurable start time and duration
 */
contract CreateVestingSchedule is Script {
    /// @notice The beneficiary address that will receive vested tokens
    address public constant BENEFICIARY = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    /// @notice The total amount of tokens to vest (1000 tokens with 18 decimals)
    uint256 public constant TOTAL_AMOUNT = 1000 ether;

    /// @notice The start time for vesting (current time by default)
    uint256 public START_TIME = block.timestamp;

    /// @notice The duration of the vesting period (30 days)
    uint256 public constant DURATION = 30 days;

    /**
     * @notice Creates a vesting schedule for the specified beneficiary
     * @dev Mints tokens to the owner, approves the vesting wallet, and creates the schedule
     * @param vestingWalletAddress The address of the deployed VestingWallet contract
     * @param tokenAddress The address of the deployed MockToken contract
     */
    function createVestingScheduleVestingWallet(address vestingWalletAddress, address tokenAddress) public {
        VestingWallet vestingWallet = VestingWallet(vestingWalletAddress);
        MockToken token = MockToken(tokenAddress);

        address contractOwner = vestingWallet.owner();
        require(contractOwner != address(0), "Contract owner not set");

        console.log("Running createVestingSchedule script...");

        vm.startBroadcast(contractOwner);

        // Mint tokens to the owner
        token.mint(contractOwner, TOTAL_AMOUNT);

        // Approve the vesting wallet to spend the tokens
        token.approve(address(vestingWallet), TOTAL_AMOUNT);

        // Create the vesting schedule
        vestingWallet.createVestingSchedule(BENEFICIARY, TOTAL_AMOUNT, START_TIME, DURATION);

        vm.stopBroadcast();

        console.log("Vesting schedule created for beneficiary: %s", BENEFICIARY);
        console.log("Start time (Unix timestamp): %s", START_TIME);
        console.log("Duration (seconds): %s", DURATION);
        console.log("Total amount: %s", TOTAL_AMOUNT);
    }

    /**
     * @notice Main function to run the script
     * @dev Retrieves the most recent deployments and creates a vesting schedule
     */
    function run() external {
        address vestingWalletAddress = DevOpsTools.get_most_recent_deployment("VestingWallet", block.chainid);
        address tokenAddress = DevOpsTools.get_most_recent_deployment("MockToken", block.chainid);

        console.log("VestingWallet address: %s", vestingWalletAddress);
        console.log("Token address: %s", tokenAddress);

        require(vestingWalletAddress != address(0), "VestingWallet not found");
        require(tokenAddress != address(0), "MockToken not found");

        createVestingScheduleVestingWallet(vestingWalletAddress, tokenAddress);
    }
}

/**
 * @title ReleaseToken
 * @author Your Name
 * @notice Script to release vested tokens to a beneficiary
 * @dev This script releases all available vested tokens to the beneficiary
 */
contract ReleaseToken is Script {
    /// @notice The beneficiary address that will receive vested tokens
    address public constant BENEFICIARY = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    /**
     * @notice Releases vested tokens from the vesting wallet
     * @param mostRecentlyDeployed The address of the deployed VestingWallet contract
     */
    function releaseVestingWallet(address mostRecentlyDeployed) internal {
        console.log("Releasing vested tokens to beneficiary: %s", BENEFICIARY);

        // Create contract instance
        VestingWallet vestingWallet = VestingWallet(mostRecentlyDeployed);

        // Check if beneficiary has a vesting schedule
        (uint256 totalAmount, uint256 startTime, uint256 duration, uint256 releasedAmount) =
            vestingWallet.s_vestingSchedules(BENEFICIARY);

        require(totalAmount > 0, "No vesting schedule found for beneficiary");

        console.log("Vesting schedule details:");
        console.log("Total amount: %s", totalAmount);
        console.log("Start time: %s", startTime);
        console.log("Duration: %s", duration);
        console.log("Already released: %s", releasedAmount);

        // Check releasable amount
        uint256 releasable = vestingWallet.releasableAmount(BENEFICIARY);
        console.log("Releasable amount for beneficiary: %s", releasable);

        if (releasable == 0) {
            console.log("No tokens available for release at this time");
            return;
        }

        vm.startBroadcast();
        vestingWallet.release(BENEFICIARY);
        vm.stopBroadcast();

        console.log("Released %s tokens to beneficiary: %s", releasable, BENEFICIARY);

        // Check new released amount
        (,,, uint256 newReleasedAmount) = vestingWallet.s_vestingSchedules(BENEFICIARY);
        console.log("Total released amount for beneficiary: %s", newReleasedAmount);
    }

    /**
     * @notice Main function to run the script
     * @dev Retrieves the most recent VestingWallet deployment and releases tokens
     */
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("VestingWallet", block.chainid);
        console.log("VestingWallet address: %s", mostRecentlyDeployed);
        require(mostRecentlyDeployed != address(0), "VestingWallet not found");

        releaseVestingWallet(mostRecentlyDeployed);
    }
}

/**
 * @title TimeWarpReleaseToken
 * @author Your Name
 * @notice Script to warp time and then release vested tokens
 * @dev This script warps time to simulate the passage of time before releasing tokens
 */
contract TimeWarpReleaseToken is Script {
    /// @notice The beneficiary address that will receive vested tokens
    address public constant BENEFICIARY = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    /// @notice The amount of time to warp forward (1 day by default)
    uint256 public constant WARP_TIME = 1 days;

    /**
     * @notice Warps time and releases vested tokens from the vesting wallet
     * @param mostRecentlyDeployed The address of the deployed VestingWallet contract
     */
    function timeWarpReleaseVestingWallet(address mostRecentlyDeployed) internal {
        console.log("Warping time and releasing vested tokens to beneficiary: %s", BENEFICIARY);

        // Create contract instance
        VestingWallet vestingWallet = VestingWallet(mostRecentlyDeployed);

        // Check if beneficiary has a vesting schedule
        (uint256 totalAmount, uint256 startTime, uint256 duration, uint256 releasedAmount) =
            vestingWallet.s_vestingSchedules(BENEFICIARY);

        require(totalAmount > 0, "No vesting schedule found for beneficiary");

        console.log("Vesting schedule details:");
        console.log("Total amount: %s", totalAmount);
        console.log("Start time: %s", startTime);
        console.log("Duration: %s", duration);
        console.log("Already released: %s", releasedAmount);

        // Warp time forward
        console.log("Warping time by %s seconds...", WARP_TIME);
        vm.warp(block.timestamp + WARP_TIME);
        console.log("New block timestamp: %s", block.timestamp);

        // Check releasable amount
        uint256 releasable = vestingWallet.releasableAmount(BENEFICIARY);
        console.log("Releasable amount for beneficiary: %s", releasable);

        if (releasable == 0) {
            console.log("No tokens available for release at this time");
            return;
        }

        vm.startBroadcast();
        vestingWallet.release(BENEFICIARY);
        vm.stopBroadcast();

        console.log("Released %s tokens to beneficiary: %s", releasable, BENEFICIARY);

        // Check new released amount
        (,,, uint256 newReleasedAmount) = vestingWallet.s_vestingSchedules(BENEFICIARY);
        console.log("Total released amount for beneficiary: %s", newReleasedAmount);
    }

    /**
     * @notice Main function to run the script
     * @dev Retrieves the most recent VestingWallet deployment, warps time, and releases tokens
     */
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("VestingWallet", block.chainid);
        console.log("VestingWallet address: %s", mostRecentlyDeployed);
        require(mostRecentlyDeployed != address(0), "VestingWallet not found");

        timeWarpReleaseVestingWallet(mostRecentlyDeployed);
    }
}
