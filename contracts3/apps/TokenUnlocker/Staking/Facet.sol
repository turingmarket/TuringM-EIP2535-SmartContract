// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Facet} from "../../../Facet.sol";
import {StakingBase} from "./Base.sol";
import {VoteBase} from "../Vote/Base.sol";
import {IStakingFacet} from "./IFacet.sol";
import {UserNonceBase} from "../../../facets/UserNonce/Base.sol";
import {AccessControlBase} from "../../../facets/AccessControl/Base.sol";
import "../../../utils/IERC20.sol";

contract StakingFacet is
    IStakingFacet,
    StakingBase,
    VoteBase,
    AccessControlBase,
    UserNonceBase,
    Facet
{
    function StakingFacet_init(
        uint8 roleA,
        uint8 roleB,
        uint8 roleC
    ) external onlyInitializing {
        // A level
        _setFunctionAccess(this.setStakingToken.selector, roleA, true);
        // B level
        _setFunctionAccess(this.unstake.selector, roleB, true);
        // C level
        _setFunctionAccess(this.stake.selector, roleC, true);

        _addInterface(type(IStakingFacet).interfaceId);
    }

    function setStakingToken(
        address tokenAddress,
        bool isEnabled
    ) external protected {
        s.enabledStakingTokenMap[tokenAddress] = isEnabled;
    }

    function stake(
        address userAddress,
        address tokenAddress,
        uint256 amount,
        uint256 nonce,
        bytes memory userSig
    ) external whenNotPaused protected nonReentrant {
        require(tokenAddress != address(0), "Invalid token address");
        require(
            s.enabledStakingTokenMap[tokenAddress] == true,
            "tokenAddress is not allowed for staking"
        );
        require(amount > 0, "Amount must be greater than 0");
        _useNonce(userAddress, nonce);

        _verifySignature(
            userAddress,
            userSig,
            abi.encode(TYPEHASH_STAKE, userAddress, tokenAddress, amount, nonce)
        );
        require(
            IERC20(tokenAddress).transferFrom(
                userAddress,
                address(this),
                amount
            ),
            "Transfer token into staking contract failed"
        );

        s.totalStakingAmountMap[tokenAddress] += amount;
        s.userStakingAmountMap[tokenAddress][userAddress] += amount;

        s.stakeSchedules.push(
            StakeSchedule({
                userAddress: userAddress,
                tokenAddress: tokenAddress,
                amount: amount,
                startTime: block.timestamp,
                isUnstaked: false
            })
        );
        uint256 scheduleIndex = s.stakeSchedules.length - 1;
        s.userStakeScheduleMap[userAddress].push(scheduleIndex);
        _addPendingVotingPowerStakeScheduleIndex(userAddress, scheduleIndex);

        emit Staked(userAddress, tokenAddress, amount, nonce, scheduleIndex);
    }

    function unstake(
        uint256 scheduleIndex,
        uint256 nonce,
        bytes memory userSig
    ) external whenNotPaused protected nonReentrant {
        require(
            scheduleIndex < s.stakeSchedules.length,
            "Invalid schedule index"
        );

        StakeSchedule memory schedule = s.stakeSchedules[scheduleIndex];
        address userAddress = schedule.userAddress;
        address tokenAddress = schedule.tokenAddress;
        uint256 amount = schedule.amount;

        _useNonce(userAddress, nonce);
        _verifySignature(
            userAddress,
            userSig,
            abi.encode(TYPEHASH_UNSTAKE, scheduleIndex, nonce)
        );

        require(schedule.isUnstaked == false, "Stake has been unstaked");
        s.stakeSchedules[scheduleIndex].isUnstaked = true;

        require(
            IERC20(tokenAddress).transfer(userAddress, amount),
            "Transfer failed"
        );
        s.totalStakingAmountMap[tokenAddress] -= amount;
        s.userStakingAmountMap[tokenAddress][userAddress] -= amount;

        _removeVotingPowerFromStake(userAddress, scheduleIndex, amount);
        _removeStakeScheduleIndex(userAddress, scheduleIndex);

        emit Unstaked(userAddress, tokenAddress, amount, nonce, scheduleIndex);
    }
}
