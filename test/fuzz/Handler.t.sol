// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {VestingWallet} from "src/VestingWallet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockToken} from "src/MockToken.sol";

contract Handler is Test {
    VestingWallet public vestingWallet;
    MockToken public token;
    address public owner;
    address[] public beneficiaries;
    mapping(address => bool) public isBeneficiary;

    // Track expected state
    mapping(address => uint256) public expectedVested;
    mapping(address => uint256) public expectedReleased;
    mapping(address => uint256) public expectedReleasable;

    uint256 public totalVested;
    uint256 public totalReleased;

    // For fuzz testing
    uint256 public constant MIN_AMOUNT = 1 ether;
    uint256 public constant MAX_AMOUNT = 1000 ether;
    uint256 public constant MIN_DURATION = 1 days;
    uint256 public constant MAX_DURATION = 365 days;

    constructor(VestingWallet _vestingWallet, MockToken _token, address _owner) {
        vestingWallet = _vestingWallet;
        token = _token;
        owner = _owner;
    }

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

    // Helper functions for invariant tests
    function getBeneficiaryCount() public view returns (uint256) {
        return beneficiaries.length;
    }

    function getBeneficiary(uint256 index) public view returns (address) {
        return beneficiaries[index];
    }
}
