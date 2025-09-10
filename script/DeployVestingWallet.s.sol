// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {VestingWallet} from "src/VestingWallet.sol";
import {MockToken} from "src/MockToken.sol";

contract DeployVestingWallet is Script {
    function run() external returns (VestingWallet, MockToken) {
        console.log("Deploying VestingWallet...");

        vm.startBroadcast();

        MockToken token = new MockToken("Vest Token", "VEST");
        VestingWallet vestingWallet = new VestingWallet(address(token));

        console.log("Token deployed at:", address(token));
        console.log("VestingWallet deployed at:", address(vestingWallet));
        console.log("Token address in VestingWallet:", address(vestingWallet.getTokenAddress()));

        vm.stopBroadcast();

        return (vestingWallet, token);
    }
}
