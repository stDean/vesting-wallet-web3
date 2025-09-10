// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {VestingWallet} from "src/VestingWallet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockToken} from "src/MockToken.sol";
import {DeployVestingWallet} from "script/DeployVestingWallet.s.sol";

contract VestingWalletOpenInvariantTest is StdInvariant, Test {
    VestingWallet vestingWallet;
    MockToken token;
    DeployVestingWallet deployer;
    address owner;

    uint256 constant VESTING_AMOUNT = 1000 ether;
    uint256 public constant VESTING_DURATION = 365 days;
    uint256 public START_TIME = block.timestamp + 1 days;
    address public beneficiary = makeAddr("beneficiary");
    address randomCaller = makeAddr("randomCaller");

    function setUp() public {
        deployer = new DeployVestingWallet();
        (vestingWallet, token) = deployer.run();

        owner = vestingWallet.getContractOwner();
        // Mint tokens to owner
        token.mint(owner, 1_000_000 ether);

        vm.prank(owner);
        token.approve(address(vestingWallet), 1_000_000 ether);
    }

    function testOpenInvariant_anyoneCanRelease() public {
        vm.prank(owner);
        vestingWallet.createVestingSchedule(beneficiary, VESTING_AMOUNT, START_TIME, VESTING_DURATION);

        // Warp to halfway through vesting period
        vm.warp(START_TIME + VESTING_DURATION / 2);

        //  // Anyone should be able to call release
        vm.prank(randomCaller);
        vestingWallet.release(makeAddr("beneficiary"));

        (,,, uint256 releasedAmount) = vestingWallet.s_vestingSchedules(beneficiary);
        assertEq(releasedAmount, VESTING_AMOUNT / 2);
    }
}
