// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockToken
 * @author Dean
 * @notice A mock ERC20 token contract for testing and development purposes
 * @dev This contract extends OpenZeppelin's ERC20 implementation with additional minting functionality
 * It is designed to be used in test environments to simulate real ERC20 tokens without requiring
 * actual token purchases or transfers on mainnet
 */
contract MockToken is ERC20 {
    /**
     * @notice Initializes the mock token with a name and symbol
     * @dev Mints an initial supply of 1,000,000 tokens (with 18 decimals) to the deployer
     * @param name The name of the token (e.g., "Test Token")
     * @param symbol The symbol of the token (e.g., "TEST")
     */
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    /**
     * @notice Mints new tokens to a specified address
     * @dev This function allows creating new token supply without any restrictions
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint (in base units, not accounting for decimals)
     * @custom:warning This function has no access controls and is intended for testing only
     * @custom:warning Using this function can arbitrarily inflate the token supply
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
