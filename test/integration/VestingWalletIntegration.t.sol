// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {VestingWallet} from "src/VestingWallet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockToken} from "src/MockToken.sol";
import {DeployVestingWallet} from "script/DeployVestingWallet.s.sol";
import {CreateVestingSchedule, ReleaseToken} from "script/Interactions.s.sol";

contract VestingWalletIntegrationTest is Test {
    DeployVestingWallet deployer;
    VestingWallet public vestingWallet;
    MockToken public token;
    address owner;

    address public beneficiary = makeAddr("beneficiary");
    address public randomUser = makeAddr("randomUser");

    uint256 public constant VESTING_AMOUNT = 1000 ether;
    uint256 public constant VESTING_DURATION = 30 days;
    uint256 public startTime;

    function setUp() external {
        deployer = new DeployVestingWallet();
        (vestingWallet, token) = deployer.run();
        owner = vestingWallet.getContractOwner();

        // Set up initial state
        startTime = block.timestamp + 1 days;

        // Mint tokens to owner
        token.mint(owner, 10_0000 ether);
    }
}
