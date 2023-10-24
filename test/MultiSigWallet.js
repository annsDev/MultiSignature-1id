const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
// const hre = require("hardhat");
const { ethers } = require("hardhat");
const { hours } = require("@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time/duration");



describe("MultiSigWallet", function () {
    async function DeployMultiSigWallet() {
        const [deployer, secondOwner, thirdOwner, newOwner, nonOwner] = await ethers.getSigners();
        const owners = [secondOwner, thirdOwner];

        const Multisig = await ethers.getContractFactory("MultiSigWallet");
        const ethToWei = ethers.parseEther('1')
        const MultisigContract = await Multisig.deploy(deployer, 20, 3, ethToWei, owners);

        const depositAmount = ethers.parseEther("4");
        await MultisigContract.depositEther({ value: depositAmount });
        await MultisigContract.deposit();

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
        it("Should fail if the new limit is null", async function () {
            const { MultisigContract, nonOwner } = await loadFixture(DeployMultiSigWallet);

            await expect(MultisigContract.updateDailyLimit(0))
                .to.be.revertedWith("Limit can not be zero");
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

    describe("removeOwner() function", function () {
        it("Should be able to remove owner", async function () {
            const { MultisigContract, secondOwner } = await loadFixture(DeployMultiSigWallet);

            await MultisigContract.removeOwner(secondOwner);
        });
        it("Should fail if owner does not exist", async function () {
            const { MultisigContract, nonOwner } = await loadFixture(DeployMultiSigWallet);

            await expect(MultisigContract.removeOwner(nonOwner))
                .to.be.revertedWithCustomError(MultisigContract, "OwnerNotExist");
        });
        it("Should fail if try to remove last owner of the safe", async function () {
            const { MultisigContract, secondOwner, thirdOwner, deployer } = await loadFixture(DeployMultiSigWallet);

            await MultisigContract.removeOwner(secondOwner);
            await MultisigContract.removeOwner(thirdOwner);


            await expect(MultisigContract.removeOwner(deployer))
                .to.be.revertedWith("Cannot remove the last owner");
        });
        it("Should fail if non-owner tries to add new owner", async function () {
            const { MultisigContract, secondOwner, nonOwner } = await loadFixture(DeployMultiSigWallet);

            const multisigWithNonOwner = MultisigContract.connect(nonOwner);

            await expect(multisigWithNonOwner.removeOwner(secondOwner))
                .to.be.revertedWithCustomError(MultisigContract, "OnlyOwnerAllowed");
        });
    });

    describe("replaceOwner() function", function () {
        it("Should be able to replace the owner", async function () {
            const { MultisigContract, thirdOwner, newOwner } = await loadFixture(DeployMultiSigWallet);

            await MultisigContract.replaceOwner(thirdOwner.address, newOwner.address);

            const ownerArray = await MultisigContract.owners(2);

            expect(newOwner.address).to.equal(ownerArray);
        });
        it("Should fail if old owner does not exist", async function () {
            const { MultisigContract, nonOwner, newOwner } = await loadFixture(DeployMultiSigWallet);

            await expect(MultisigContract.replaceOwner(nonOwner.address, newOwner.address))
                .to.be.revertedWithCustomError(MultisigContract, "OwnerNotExist");
        });
        it("Should fail if new owner already exist", async function () {
            const { MultisigContract, secondOwner, thirdOwner } = await loadFixture(DeployMultiSigWallet);

            await expect(MultisigContract.replaceOwner(secondOwner.address, thirdOwner.address))
                .to.be.revertedWithCustomError(MultisigContract, "OwnerAlreadyExists");
        });
        it("Should fail if non-owner tries to replace", async function () {
            const { MultisigContract, thirdOwner, newOwner, nonOwner } = await loadFixture(DeployMultiSigWallet);

            const multisigWithNonOwner = MultisigContract.connect(nonOwner);

            await expect(multisigWithNonOwner.replaceOwner(thirdOwner.address, newOwner.address))
                .to.be.revertedWithCustomError(MultisigContract, "OnlyOwnerAllowed");
        });
    });

    describe("changeRequirement() function", function () {
        it("Should be able to update the threshold", async function () {
            const { MultisigContract } = await loadFixture(DeployMultiSigWallet);

            await MultisigContract.changeRequirement(2);
            const thresholdValue = await MultisigContract.required();

            expect(thresholdValue).to.equal(2);
        });
        it("Should fail if threshold is greater than owners length", async function () {
            const { MultisigContract } = await loadFixture(DeployMultiSigWallet);

            await expect(MultisigContract.changeRequirement(4))
                .to.be.revertedWith("Validation Failed!");
        });
        it("Should fail if non-owner tries to update the threshold value", async function () {
            const { MultisigContract, nonOwner } = await loadFixture(DeployMultiSigWallet);

            const multisigWithNonOwner = MultisigContract.connect(nonOwner);

            await expect(multisigWithNonOwner.changeRequirement(2))
                .to.be.revertedWithCustomError(MultisigContract, "OnlyOwnerAllowed");
        });
    });

    describe("submitTransaction() function", function () {
        it("Any owner should be able to add the transaction", async function () {
            const { MultisigContract, newOwner } = await loadFixture(DeployMultiSigWallet);
            const destination = newOwner;
            var value = '1000000000000000';
            const bytesData = '0x74657374207472616e73616374696f6e00000000000000000000000000000000';
            var expireTime = await time.latest() + 100;

            await MultisigContract.submitTransaction(destination, value, bytesData, expireTime);
            const transactionId = await MultisigContract.transactionCount();

            expect(transactionId).to.equal(1);
        });
        it("Should fail if expire time is less than the current time", async function () {
            const { MultisigContract, newOwner } = await loadFixture(DeployMultiSigWallet);
            const destination = newOwner;
            var value = '1000000000000000';
            const bytesData = '0x74657374207472616e73616374696f6e00000000000000000000000000000000';
            var expireTime = await time.latest() - 100;

            await expect(MultisigContract.submitTransaction(destination, value, bytesData, expireTime))
                .to.be.revertedWithCustomError(MultisigContract, "InvalidBlockTimeStamp");
        });
        it("Should fail if destination address is null", async function () {
            const { MultisigContract, newOwner } = await loadFixture(DeployMultiSigWallet);
            const destination = ethers.ZeroAddress;
            var value = '1000000000000000';
            const bytesData = '0x74657374207472616e73616374696f6e00000000000000000000000000000000';
            var expireTime = await time.latest() + 100;

            await expect(MultisigContract.submitTransaction(destination, value, bytesData, expireTime))
                .to.be.revertedWithCustomError(MultisigContract, "InvalidAddress");
        });
        it("Should fail if non-owner tries to submit the transaction", async function () {
            const { MultisigContract, nonOwner, newOwner } = await loadFixture(DeployMultiSigWallet);
            const destination = newOwner;
            var value = '1000000000000000';
            const bytesData = '0x74657374207472616e73616374696f6e00000000000000000000000000000000';
            var expireTime = await time.latest() + 100;

            const multisigWithNonOwner = MultisigContract.connect(nonOwner);

            await expect(multisigWithNonOwner.submitTransaction(destination, value, bytesData, expireTime))
                .to.be.revertedWithCustomError(MultisigContract, "OwnerNotExist");
        });
    });

    describe("executeTransaction() function", function () {
        it("Should be able to execute the transaction", async function () {
            const { MultisigContract, newOwner } = await loadFixture(DeployMultiSigWallet);

            const destination = newOwner;
            const value = ethers.parseEther('0.001')
            const bytesData = '0x74657374207472616e73616374696f6e00000000000000000000000000000000';
            const expireTime = (await time.latest()) + 3600;

            const v = ['27', '28', '28'];
            const r = ['0x83e5ac9f69ae952b6848a3d602aaca0c730ef3e55946d6f53fdfa4f240515753', '0x327f6a2294596a4e9400842f5172e2e768dd01e8501ed0877697f1c58ac418a3', '0xde1477afcd1b1c627ea42ea3acf1d9c002fc3c0fe99b8e56136a73553542690e'];
            const s = ['0x2d47cadbc03f0d00977f84df41ee4068ba2c6411ab4a102c081bf94ffef8fb5e', '0x4e0b2acb455712d1117eadfa6a0f04685ab2c43a7e2d620b6025465754fa6974', '0x3d17bd4fcb46646a25d633c579779e6217cad4f5006b20fcb7ad3bfa2e28e0d5'];

            await MultisigContract.submitTransaction(destination, value, bytesData, expireTime);

            await MultisigContract.executeTransaction(0, v, r, s);

            const contractBalance = await MultisigContract.contractBalance();
            const weiBalance = contractBalance.toString();

            expect(weiBalance).to.equal('3999000000000000000');
        });
        it("Should fail if any owner try to perfom already executed transaction", async function () {
            const { MultisigContract, newOwner } = await loadFixture(DeployMultiSigWallet);

            const destination = newOwner;
            const value = ethers.parseEther('0.001')
            const bytesData = '0x74657374207472616e73616374696f6e00000000000000000000000000000000';
            const expireTime = (await time.latest()) + 3600;

            const v = ['27', '28', '28'];
            const r = ['0x83e5ac9f69ae952b6848a3d602aaca0c730ef3e55946d6f53fdfa4f240515753', '0x327f6a2294596a4e9400842f5172e2e768dd01e8501ed0877697f1c58ac418a3', '0xde1477afcd1b1c627ea42ea3acf1d9c002fc3c0fe99b8e56136a73553542690e'];
            const s = ['0x2d47cadbc03f0d00977f84df41ee4068ba2c6411ab4a102c081bf94ffef8fb5e', '0x4e0b2acb455712d1117eadfa6a0f04685ab2c43a7e2d620b6025465754fa6974', '0x3d17bd4fcb46646a25d633c579779e6217cad4f5006b20fcb7ad3bfa2e28e0d5'];

            await MultisigContract.submitTransaction(destination, value, bytesData, expireTime);
            await MultisigContract.executeTransaction(0, v, r, s);

            await expect(MultisigContract.executeTransaction(0, v, r, s))
                .to.be.revertedWithCustomError(MultisigContract, "TransactionAlreadyExecuted");
        });
        it("Should fail if transaction has been expired", async function () {
            const { MultisigContract, newOwner } = await loadFixture(DeployMultiSigWallet);

            const destination = newOwner;
            const value = ethers.parseEther('0.001')
            const bytesData = '0x74657374207472616e73616374696f6e00000000000000000000000000000000';
            const expireTime = (await time.latest() + 100);
            const futureTime = (await time.latest()) + 3600;

            const v = ['27', '28', '28'];
            const r = ['0x83e5ac9f69ae952b6848a3d602aaca0c730ef3e55946d6f53fdfa4f240515753', '0x327f6a2294596a4e9400842f5172e2e768dd01e8501ed0877697f1c58ac418a3', '0xde1477afcd1b1c627ea42ea3acf1d9c002fc3c0fe99b8e56136a73553542690e'];
            const s = ['0x2d47cadbc03f0d00977f84df41ee4068ba2c6411ab4a102c081bf94ffef8fb5e', '0x4e0b2acb455712d1117eadfa6a0f04685ab2c43a7e2d620b6025465754fa6974', '0x3d17bd4fcb46646a25d633c579779e6217cad4f5006b20fcb7ad3bfa2e28e0d5'];

            await MultisigContract.submitTransaction(destination, value, bytesData, expireTime);
            await time.increaseTo(futureTime);

            await expect(MultisigContract.executeTransaction(0, v, r, s))
                .to.be.revertedWithCustomError(MultisigContract, "TransactionExpired");
        });
        it("Should fail if signature does not match with correct address", async function () {
            const { MultisigContract, newOwner } = await loadFixture(DeployMultiSigWallet);

            const destination = newOwner;
            const value = ethers.parseEther('0.001')
            const bytesData = '0x74657374207472616e73616374696f6e00000000000000000000000000000000';
            const expireTime = (await time.latest() + 100);

            const v = ['27', '28', '28'];
            const r = ['0x83e5ac9f69ae952b6848a3d602aaca0c730ef3e55946d6f53fdfa4f240515753', '0x327f6a2294596a4e9400842f5172e2e768dd01e8501ed0877697f1c58ac418a3', '0xde1477afcd1b1c627ea42ea3acf1d9c002fc3c0fe99b8e56136a73553542690e'];
            const s = ['0x2d47cadbc03f0d00977f84df41ef4068ba2c6411ab4a102c081bf94ffef8fb5e', '0x4e0b2acb455712d1117eadfa6a0f04685ab2c43a7e2d620b6025465754fa6974', '0x3d17bd4fcb46646a25d633c579779e6217cad4f5006b20fcb7ad3bfa2e28e0d5'];

            await MultisigContract.submitTransaction(destination, value, bytesData, expireTime);

            await expect(MultisigContract.executeTransaction(0, v, r, s))
                .to.be.revertedWith("Address does not match with signature");
        });
        it("Should fail if not all the owners signed the transaction", async function () {
            const { MultisigContract, newOwner } = await loadFixture(DeployMultiSigWallet);

            const destination = newOwner;
            const value = ethers.parseEther('0.001')
            const bytesData = '0x74657374207472616e73616374696f6e00000000000000000000000000000000';
            const expireTime = (await time.latest() + 100);

            const v = ['27', '28', '28'];
            const r = ['0x83e5ac9f69ae952b6848a3d602aaca0c730ef3e55946d6f53fdfa4f240515753', '0xde1477afcd1b1c627ea42ea3acf1d9c002fc3c0fe99b8e56136a73553542690e'];
            const s = ['0x2d47cadbc03f0d00977f84df41ee4068ba2c6411ab4a102c081bf94ffef8fb5e', '0x4e0b2acb455712d1117eadfa6a0f04685ab2c43a7e2d620b6025465754fa6974', '0x3d17bd4fcb46646a25d633c579779e6217cad4f5006b20fcb7ad3bfa2e28e0d5'];

            await MultisigContract.submitTransaction(destination, value, bytesData, expireTime);

            await expect(MultisigContract.executeTransaction(0, v, r, s))
                .to.be.revertedWith("Signatures should be equal to required threshold!");
        });

    });

});