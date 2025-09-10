// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title VestingWallet
 * @author Dean
 * @notice A contract that handles the vesting of ERC20 tokens for beneficiaries over a linear vesting period.
 * @dev This contract allows an owner to create vesting schedules for beneficiaries. Tokens are vested linearly
 * over a specified duration starting from a defined start time. Anyone can trigger the release of vested tokens
 * to the beneficiary. The contract uses OpenZeppelin's Ownable for access control and SafeERC20 for safe token transfers.
 */
contract VestingWallet is Ownable {
    using SafeERC20 for IERC20;

    // Custom Errors
    error VestingWallet__ZeroTokenAddress();
    error VestingWallet__ZeroBeneficiaryAddress();
    error VestingWallet__ZeroAmount();
    error VestingWallet__ZeroDuration();
    error VestingWallet__VestingScheduleAlreadyExists();
    error VestingWallet__NoVestingSchedule();
    error VestingWallet__NoTokensToRelease();

    /**
     * @dev Struct to store vesting schedule details for each beneficiary
     * @param totalAmount The total amount of tokens allocated to this specific beneficiary (not the contract's total balance)
     * @param startTime The timestamp when vesting starts for this beneficiary
     * @param duration The duration of the vesting period in seconds for this beneficiary
     * @param releasedAmount The amount of tokens already released to this beneficiary
     */
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 duration;
        uint256 releasedAmount;
    }

    /// @notice Immutable ERC20 token that will be vested
    IERC20 private immutable i_token;

    /// @notice Mapping from beneficiary address to their vesting schedule
    mapping(address => VestingSchedule) public s_vestingSchedules;

    /**
     * @dev Emitted when a new vesting schedule is created for a beneficiary
     * @param beneficiary The address of the beneficiary
     * @param totalAmount The total amount of tokens allocated to this specific beneficiary
     * @param startTime The timestamp when vesting starts for this beneficiary
     * @param duration The duration of the vesting period in seconds for this beneficiary
     */
    event VestingScheduleCreated(address indexed beneficiary, uint256 totalAmount, uint256 startTime, uint256 duration);

    /**
     * @dev Emitted when vested tokens are released to a beneficiary
     * @param beneficiary The address of the beneficiary
     * @param amount The amount of tokens released to this beneficiary
     */
    event TokensReleased(address indexed beneficiary, uint256 amount);

    /**
     * @notice Initializes the contract with the token to be vested
     * @dev Sets the contract owner to the deployer and initializes the token address
     * @param _token The address of the ERC20 token to be vested
     * @custom:requirement Token address must not be zero address
     */
    constructor(address _token) Ownable(msg.sender) {
        if (_token == address(0)) revert VestingWallet__ZeroTokenAddress();
        i_token = IERC20(_token);
    }

    /**
     * @notice Creates a new vesting schedule for a beneficiary
     * @dev Only callable by the owner. Transfers tokens from the owner to this contract.
     * @param _beneficiary The address of the beneficiary who will receive the vested tokens
     * @param _totalAmount The total amount of tokens allocated to this specific beneficiary (not the contract's total balance)
     * @param _startTime The timestamp when vesting should start for this beneficiary
     * @param _duration The duration of the vesting period in seconds for this beneficiary
     * @custom:requirement Beneficiary address must not be zero address
     * @custom:requirement Total amount must be greater than zero
     * @custom:requirement Duration must be greater than zero
     * @custom:requirement A vesting schedule must not already exist for the beneficiary
     * @custom:emits VestingScheduleCreated event on success
     */
    function createVestingSchedule(address _beneficiary, uint256 _totalAmount, uint256 _startTime, uint256 _duration)
        external
        onlyOwner
    {
        if (_beneficiary == address(0)) revert VestingWallet__ZeroBeneficiaryAddress();
        if (_totalAmount == 0) revert VestingWallet__ZeroAmount();
        if (_duration == 0) revert VestingWallet__ZeroDuration();
        if (s_vestingSchedules[_beneficiary].totalAmount != 0) revert VestingWallet__VestingScheduleAlreadyExists();

        // Transfer tokens to this contract
        i_token.safeTransferFrom(msg.sender, address(this), _totalAmount);

        s_vestingSchedules[_beneficiary] =
            VestingSchedule({totalAmount: _totalAmount, startTime: _startTime, duration: _duration, releasedAmount: 0});

        emit VestingScheduleCreated(_beneficiary, _totalAmount, _startTime, _duration);
    }

    /**
     * @notice Releases vested tokens to the beneficiary
     * @dev Can be called by anyone to release vested tokens to the beneficiary
     * @param _beneficiary The address of the beneficiary to release tokens for
     * @custom:requirement A vesting schedule must exist for the beneficiary
     * @custom:requirement There must be releasable tokens available
     * @custom:emits TokensReleased event on success
     */
    function release(address _beneficiary) external {
        VestingSchedule storage schedule = s_vestingSchedules[_beneficiary];
        if (schedule.totalAmount == 0) revert VestingWallet__NoVestingSchedule();

        uint256 releasable = vestedAmount(_beneficiary) - schedule.releasedAmount;
        if (releasable == 0) revert VestingWallet__NoTokensToRelease();

        schedule.releasedAmount += releasable;
        i_token.safeTransfer(_beneficiary, releasable);

        emit TokensReleased(_beneficiary, releasable);
    }

    /**
     * @notice Calculates the amount of tokens that have already vested for a specific beneficiary
     * @dev Uses linear vesting calculation based on elapsed time for this specific beneficiary
     * @param _beneficiary The address of the beneficiary to check
     * @return The amount of tokens that have vested for this specific beneficiary
     */
    function vestedAmount(address _beneficiary) internal view returns (uint256) {
        VestingSchedule memory schedule = s_vestingSchedules[_beneficiary];
        if (schedule.totalAmount == 0) {
            return 0;
        }

        if (block.timestamp < schedule.startTime) {
            return 0;
        } else if (block.timestamp >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount;
        } else {
            uint256 timeElapsed = block.timestamp - schedule.startTime;
            return (schedule.totalAmount * timeElapsed) / schedule.duration;
        }
    }

    /**
     * @notice Returns the amount of tokens that can be released for a specific beneficiary
     * @dev Calculates the difference between vested amount and already released amount for this specific beneficiary
     * @param _beneficiary The address of the beneficiary to check
     * @return The amount of tokens that can be released to this specific beneficiary
     */
    function releasableAmount(address _beneficiary) external view returns (uint256) {
        return vestedAmount(_beneficiary) - s_vestingSchedules[_beneficiary].releasedAmount;
    }

    /**
     * @notice Returns the total amount of tokens held by this contract for all beneficiaries
     * @dev This is different from any individual beneficiary's totalAmount
     * @return The contract's total token balance
     */
    function contractTokenBalance() external view returns (uint256) {
        return i_token.balanceOf(address(this));
    }

    /**
     * @notice Returns the address of the ERC20 token being vested
     * @return The address of the vested token
     */
    function getTokenAddress() external view returns (address) {
        return address(i_token);
    }

    /**
     * @notice Returns the owner of the contract
     * @dev This function is added to facilitate testing and interaction with the Ownable contract
     * @return The address of the contract owner
     */
    function getContractOwner() external view returns (address) {
        return owner();
    }
}
