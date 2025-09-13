// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {VestingWalletHandler} from "test/fuzz/VestingWalletHandler.t.sol";
import {VestingWallet} from "src/VestingWallet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockToken} from "src/MockToken.sol";
import {DeployVestingWallet} from "script/DeployVestingWallet.s.sol";

contract VestingWalletInvariantTest is StdInvariant, Test {
    DeployVestingWallet deployer;
    VestingWallet public vestingWallet;
    MockToken public token;
    VestingWalletHandler handler;
    address owner;

    function setUp() external {
        deployer = new DeployVestingWallet();
        (vestingWallet, token) = deployer.run();
        owner = vestingWallet.getContractOwner();

        // Mint tokens to owner
        token.mint(owner, 1000 ether);

        handler = new VestingWalletHandler(vestingWallet, token, owner);

        // Target the handler for invariant testing
        targetContract(address(handler));

        // Exclude owner from fuzz tests
        excludeSender(owner);
    }

    /**
     * @notice Invariant: Total vested should always equal the sum of all vesting schedule amounts
     */
    function invariant_totalVested() public view {
        uint256 totalVestedInContract;

        for (uint256 i = 0; i < handler.getBeneficiaryCount(); i++) {
            address beneficiary = handler.getBeneficiary(i);
            (uint256 totalAmount,,,) = vestingWallet.s_vestingSchedules(beneficiary);
            totalVestedInContract += totalAmount;
        }

        assertEq(totalVestedInContract, handler.totalVested());
    }

    /**
     * @notice Invariant: Total released should match the sum of all released amounts
     */
    function invariant_totalReleased() public view {
        uint256 totalReleasedInContract;

        for (uint256 i = 0; i < handler.getBeneficiaryCount(); i++) {
            address beneficiary = handler.getBeneficiary(i);
            (,,, uint256 releasedAmount) = vestingWallet.s_vestingSchedules(beneficiary);
            totalReleasedInContract += releasedAmount;
        }

        assertEq(totalReleasedInContract, handler.totalReleased());
    }

    /**
     * @notice Invariant: Contract token balance should equal total vested minus total released
     */
    function invariant_contractBalance() public view {
        uint256 expectedBalance = handler.totalVested() - handler.totalReleased();
        assertEq(token.balanceOf(address(vestingWallet)), expectedBalance);
    }

    /**
     * @notice Invariant: Vested amount should never exceed total amount for any beneficiary
     */
    function invariant_vestedAmount() public view {
        for (uint256 i = 0; i < handler.getBeneficiaryCount(); i++) {
            address beneficiary = handler.getBeneficiary(i);
            (uint256 totalAmount,,,) = vestingWallet.s_vestingSchedules(beneficiary);
            uint256 vestedAmount = vestingWallet.vestedAmount(beneficiary);

            assertLe(vestedAmount, totalAmount);
        }
    }

    /**
     * @notice Invariant: Released amount should never exceed vested amount for any beneficiary
     */
    function invariant_releasedAmount() public view {
        for (uint256 i = 0; i < handler.getBeneficiaryCount(); i++) {
            address beneficiary = handler.getBeneficiary(i);
            (,,, uint256 releasedAmount) = vestingWallet.s_vestingSchedules(beneficiary);
            uint256 vestedAmount = vestingWallet.vestedAmount(beneficiary);

            assertLe(releasedAmount, vestedAmount);
        }
    }

    /**
     * @notice Invariant: Releasable amount should always equal vested minus released
     */
    function invariant_releasableAmount() public view {
        for (uint256 i = 0; i < handler.getBeneficiaryCount(); i++) {
            address beneficiary = handler.getBeneficiary(i);
            uint256 releasableAmount = vestingWallet.releasableAmount(beneficiary);
            uint256 vestedAmount = vestingWallet.vestedAmount(beneficiary);
            (,,, uint256 releasedAmount) = vestingWallet.s_vestingSchedules(beneficiary);

            assertEq(releasableAmount, vestedAmount - releasedAmount);
        }
    }

    /**
     * @notice Invariant: No duplicate beneficiaries
     */
    function invariant_noDuplicateBeneficiaries() public view {
        for (uint256 i = 0; i < handler.getBeneficiaryCount(); i++) {
            address beneficiary1 = handler.getBeneficiary(i);

            for (uint256 j = i + 1; j < handler.getBeneficiaryCount(); j++) {
                address beneficiary2 = handler.getBeneficiary(j);
                assertTrue(beneficiary1 != beneficiary2, "Duplicate beneficiary found");
            }
        }
    }
}
