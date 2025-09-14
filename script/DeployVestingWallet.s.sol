// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {VestingWallet} from "src/VestingWallet.sol";
import {MockToken} from "src/MockToken.sol";

/**
 * @title DeployVestingWallet
 * @author Dean
 * @notice Deployment script for VestingWallet and MockToken contracts
 * @dev This script handles the deployment of both the MockToken ERC20 token contract
 * and the VestingWallet contract. It also links them together by passing the token
 * address to the VestingWallet constructor.
 * 
 * @custom:deployment-script Main deployment script for the VestingWallet project
 * @custom:deployment-order 1. Deploy MockToken 2. Deploy VestingWallet with token address
 */
contract DeployVestingWallet is Script {
    /**
     * @notice Main function to run the deployment script
     * @dev Deploys MockToken first, then VestingWallet with the token address,
     * and returns both contract instances. Uses vm.startBroadcast() and vm.stopBroadcast()
     * to handle transaction broadcasting for on-chain deployment.
     * 
     * @return vestingWallet The deployed VestingWallet contract instance
     * @return token The deployed MockToken contract instance
     * 
     * @custom:step 1. Deploy MockToken with name "Vest Token" and symbol "VEST"
     * @custom:step 2. Deploy VestingWallet with the MockToken address
     * @custom:step 3. Verify the token address is correctly set in VestingWallet
     * @custom:step 4. Return both contract instances for further use
     */
    function run() external returns (VestingWallet, MockToken) {
        console.log("Deploying VestingWallet...");

        // Start broadcasting transactions for on-chain deployment
        vm.startBroadcast();

        // Deploy MockToken ERC20 contract
        MockToken token = new MockToken("Vest Token", "VEST");
        
        // Deploy VestingWallet contract with the token address
        VestingWallet vestingWallet = new VestingWallet(address(token));

        // Log deployment information
        console.log("Token deployed at:", address(token));
        console.log("VestingWallet deployed at:", address(vestingWallet));
        console.log("Token address in VestingWallet:", address(vestingWallet.getTokenAddress()));

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Return both contract instances
        return (vestingWallet, token);
    }
}