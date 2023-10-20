const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
// const hre = require("hardhat");
const { ethers } = require("hardhat");



describe("MultiSigWallet", function () {
    async function DeployMultiSigWallet() {
        const [deployer, secondOwner, thirdOwner, newOwner, nonOwner] = await ethers.getSigners();
        const owners = [secondOwner, thirdOwner];

        const Multisig = await ethers.getContractFactory("MultiSigWallet");
        const MultisigContract = await Multisig.deploy(deployer, 20, 3, 400000000, owners);

        return { MultisigContract, deployer, secondOwner, thirdOwner, newOwner, nonOwner };
    }

    describe("Constructor Validations", function () {
        it("Should deploy the contract", async function () {
            const { MultisigContract } = await loadFixture(DeployMultiSigWallet);

            return MultisigContract.target;
        });

        it("Should return the correct deployer address", async function () {
            const { MultisigContract, deployer } = await loadFixture(DeployMultiSigWallet);
            const contractDeployer = await MultisigContract.deployer();

            expect(contractDeployer).to.equal(deployer.address);
        });

        it("Should return the correct added owners", async function () {
            const { MultisigContract, deployer, secondOwner, thirdOwner } = await loadFixture(DeployMultiSigWallet);
            const ownerOne = await MultisigContract.owners(0);
            const ownerTwo = await MultisigContract.owners(1);
            const ownerThree = await MultisigContract.owners(2);

            expect(ownerOne).to.equal(deployer.address);
            expect(ownerTwo).to.equal(secondOwner.address);
            expect(ownerThree).to.equal(thirdOwner.address);
        });

        it("Should return the correct max owners limit", async function () {
            const { MultisigContract } = await loadFixture(DeployMultiSigWallet);
            const maxOwnerLimit = await MultisigContract.max_owner();

            expect(maxOwnerLimit).to.equal(20);
        });

        it("Should return the correct threshold value", async function () {
            const { MultisigContract } = await loadFixture(DeployMultiSigWallet);
            const threshold = await MultisigContract.required();

            expect(threshold).to.equal(3);
        });

        it("Should return the correct last reset time", async function () {
            const { MultisigContract } = await loadFixture(DeployMultiSigWallet);
            const latestTime = (await time.latest())
            const resetTime = await MultisigContract.lastReset();

            expect(resetTime).to.equal(latestTime);
        });

        it("Should return the correct daily withdrawl limit", async function () {
            const { MultisigContract } = await loadFixture(DeployMultiSigWallet);
            const dailyWithdrawlLimit = await MultisigContract.dailyLimit();

            expect(dailyWithdrawlLimit).to.equal(400000000);
        });

        it("Should return the correct spent today value", async function () {
            const { MultisigContract } = await loadFixture(DeployMultiSigWallet);
            const spentAmount = await MultisigContract.spentToday();

            expect(spentAmount).to.equal(0);
        });
    });

    describe("depositEther() & contractBalance() function", function () {
        it("Should deposit the ethers to contract", async function () {
            const { MultisigContract } = await loadFixture(DeployMultiSigWallet);

            const depositAmount = ethers.parseEther("1");
            await MultisigContract.depositEther({ value: depositAmount });

            const depositedAmount = await MultisigContract.deposit();

            expect(depositedAmount).to.equal(depositAmount);
        });

        it("Should return the correct contract balance", async function () {
            const { MultisigContract } = await loadFixture(DeployMultiSigWallet);

            const depositAmount = ethers.parseEther("4");
            await MultisigContract.depositEther({ value: depositAmount });

            const contractBalance = await MultisigContract.contractBalance();

            expect(contractBalance).to.equal(depositAmount);
        });
    });

    describe("updateDailyLimit() function", function () {
        it("Should update the daily withdraw limit", async function () {
            const { MultisigContract } = await loadFixture(DeployMultiSigWallet);

            const withdrawAmount = ethers.parseEther("1");
            await MultisigContract.updateDailyLimit(withdrawAmount);

            const dailyLimit = await MultisigContract.dailyLimit();

            expect(dailyLimit).to.equal(withdrawAmount);
        });
        it("Should fail if non-owner tries to update the limit", async function () {
            const { MultisigContract, nonOwner } = await loadFixture(DeployMultiSigWallet);

            const withdrawAmount = ethers.parseEther("1");
            const multisigWithNonOwner = MultisigContract.connect(nonOwner);

            await expect(multisigWithNonOwner.updateDailyLimit(withdrawAmount))
                .to.be.revertedWithCustomError(MultisigContract, "OnlyOwnerAllowed");
        });
    });

    describe("updateMaxOwnerLimit() function", function () {
        it("Should update the maximum owner limit", async function () {
            const { MultisigContract } = await loadFixture(DeployMultiSigWallet);

            await MultisigContract.updateMaxOwnerLimit(3);
            const ownerLimit = await MultisigContract.max_owner();

            expect(ownerLimit).to.equal(3);
        });
        it("Should fail if non-owner tries to update maximum owner limit", async function () {
            const { MultisigContract, nonOwner } = await loadFixture(DeployMultiSigWallet);

            const multisigWithNonOwner = MultisigContract.connect(nonOwner);

            await expect(multisigWithNonOwner.updateMaxOwnerLimit(3))
                .to.be.revertedWithCustomError(MultisigContract, "OnlyOwnerAllowed");
        });
        it("Should fail if provided number is less than current owners length", async function () {
            const { MultisigContract, deployer } = await loadFixture(DeployMultiSigWallet);

            const multisigWithNonOwner = MultisigContract.connect(deployer);

            await expect(multisigWithNonOwner.updateMaxOwnerLimit(0))
                .to.be.revertedWithCustomError(MultisigContract, "OwnersCountExceeds");
        });
    });

    describe("addOwner() function", function () {
        it("Should be able to add new owner", async function () {
            const { MultisigContract, newOwner } = await loadFixture(DeployMultiSigWallet);

            await MultisigContract.addOwner(newOwner);

            const ownerArray = await MultisigContract.owners(3);

            expect(newOwner.address).to.equal(ownerArray);
        });
        it("Should fail if same owner is added twice", async function () {
            const { MultisigContract, secondOwner } = await loadFixture(DeployMultiSigWallet);

            await expect(MultisigContract.addOwner(secondOwner))
                .to.be.revertedWithCustomError(MultisigContract, "OwnerAlreadyExists");
        });
        it("Should fail if new address is null", async function () {
            const { MultisigContract } = await loadFixture(DeployMultiSigWallet);

            const invalidAddress = ethers.ZeroAddress;

            await expect(MultisigContract.addOwner(invalidAddress))
                .to.be.revertedWithCustomError(MultisigContract, "InvalidAddress");
        });
        it("Should fail if maximum number of owners reached", async function () {
            const { MultisigContract, newOwner, nonOwner } = await loadFixture(DeployMultiSigWallet);

            await MultisigContract.updateMaxOwnerLimit(3);
            await MultisigContract.addOwner(newOwner);

            await expect(MultisigContract.addOwner(nonOwner))
                .to.be.revertedWith("Maximum limit reached for owners!");
        });
        it("Should fail if non-owner tries to add new owner", async function () {
            const { MultisigContract, nonOwner, newOwner } = await loadFixture(DeployMultiSigWallet);

            const multisigWithNonOwner = MultisigContract.connect(nonOwner);

            await expect(multisigWithNonOwner.addOwner(newOwner))
                .to.be.revertedWithCustomError(MultisigContract, "OnlyOwnerAllowed");
        });
    });

});