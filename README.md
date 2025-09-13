# Vesting Wallet Smart Contract

A secure, transparent, and trustless vesting solution for ERC-20 tokens, built on Ethereum. This smart contract automates the distribution of tokens to team members, investors, and advisors according to a customizable linear vesting schedule.

## Overview

Managing token allocations with spreadsheets or promises is error-prone and lacks transparency. This Vesting Wallet contract solves that by deploying an immutable, on-chain schedule that anyone can audit. Once deployed, the rules are set in stone: tokens are released automatically over time, ensuring commitment and building trust within any project's ecosystem.

## Features

- Linear Vesting: Supports simple, linear token release over defined periods
- Permissionless Release: Anyone can trigger token releases for beneficiaries
- Transparent & Auditable: All schedules are publicly verifiable on-chain
- Secure: Built with OpenZeppelin libraries and thoroughly tested with Foundry
- Access Control: Only contract owner can create new vesting schedules
- Comprehensive Testing: Includes unit tests, fuzz tests, and invariant tests


## Use Cases

- Team & Advisor Allocation: Ensure core contributors are incentivized for the long term
- Investor Lock-ups: Prevent token dumping immediately after launch
- Token Sales & Airdrops: Distribute tokens to community gradually
- Grant Programs: Manage token distributions for ecosystem development

## Tech Stack

- Solidity (v0.8.19)
- Foundry (For development, testing, and deployment)
- OpenZeppelin Contracts (Ownable, SafeERC20 implementations)
- Ethereum Testnets (Sepolia, or local Anvil network)

## Project Structure

```text
vesting-wallet/
├── contracts/
│   ├── VestingWallet.sol      # Main vesting contract
│   └── MockToken.sol          # Mock ERC20 for testing
├── script/
│   ├── DeployVestingWallet.s.sol  # Deployment script
│   └── Interactions.s.sol     # Interaction with contact script
├── test/
│   ├── VestingWallet.t.sol    # Unit tests
│   ├── VestingWalletFuzzTest.t.sol # Fuzz tests
│   └── VestingWalletOpenInvariantTest.t.sol # Invariant tests
├── .env.example              # Environment variables template
└── README.md
```

# Getting Started

## Prerequisites

- Foundry
- Git

## Installation

1. Clone the repository:
  ```bash
    git clone https://github.com/stDean/vesting-wallet-web3.git
    cd vesting-wallet 
  ```

2. Install dependencies:
  ```bash
    forge install OpenZeppelin/openzeppelin-contracts
    forge install Cyfrin/foundry-devops
  ```

3. Set up environment variables:
  ```bash
    cp .env.example .env
    # Add your private key and RPC URL to .env
  ```

## Building & Testing

1. Build the contracts:
   ```bash
    forge build
  ```

2. Run the test suite:
  ```bash
    forge test -vvv
  ```

## Deployment

### Local Development

1. Start a local Anvil node:
  ```bash
    anvil
  ```

2. Deploy to local network:
  ```bash
    forge script script/DeployVestingWallet.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <your-private-key>
  ```

### Testnet Deployment

1. Deploy to testnet:
  ```bash
    forge script script/DeployVestingWallet.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
  ```

## Usage

### Creating Vesting Schedules

After deployment, create vesting schedules using the interaction script:
  ```bash
  forge script script/Interactions.s.sol:CreateVestingSchedule --rpc-url $RPC_URL --broadcast -vvvv
  ```

### Releasing Tokens

Release vested tokens to beneficiaries:
  ```bash
  forge script script/Interactions.s.sol:ReleaseToken --rpc-url $RPC_URL --broadcast -vvvv
  ```
## Key Functions

> createVestingSchedule(address beneficiary, uint256 totalAmount, uint256 startTime, uint256 duration)
Owner only - Creates a new vesting schedule for a beneficiary.

> release(address beneficiary)
Public - Releases vested tokens to the beneficiary. Can be called by anyone.

> vestedAmount(address beneficiary) → uint256
View - Returns the amount of tokens that have vested for a beneficiary.

> releasableAmount(address beneficiary) → uint256
View - Returns the amount of tokens available for release.

## Workflow Example

1. Deployment: Deploy the VestingWallet contract with an ERC20 token address
2. Schedule Creation: Owner creates vesting schedules for beneficiaries
3. Vesting Period: Tokens vest linearly over the specified duration
3. Token Release: Anyone can call release() to transfer vested tokens to beneficiaries
4. Completion: After the vesting period, all tokens are available for release

## Security Features

- Custom errors for gas-efficient reverts
- Access control with OpenZeppelin's Ownable
- SafeERC20 for secure token transfers
- Comprehensive test coverage (unit, fuzz, invariant tests)
- Input validation for all parameters

## Testing Strategy

This project employs a multi-layered testing approach:

1. Unit Tests: Verify individual functions and edge cases
2. Fuzz Tests: Test with random inputs to discover unexpected behavior
3. Invariant Tests: Ensure system properties always hold true
4. Integration Tests: Verify script interactions with deployed contracts

## Audit Considerations

Before using in production, consider:

1. Professional security audit
2. Additional access control features
3. Emergency stop functionality
4. Multi-sig ownership for production deployments

## License

MIT License - see LICENSE file for details

## Disclaimer

This software is provided for educational purposes only. Use at your own risk. The authors are not liable for any losses or damages resulting from using this code. Always get a professional audit before using a smart contract in production.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.