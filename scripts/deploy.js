const hre = require("hardhat");
const ethers = hre.ethers

async function main() {

  // const [dc] = await ethers.getSigners();
  // console.log('deployer::::', dc.address)

  /* ******* Factory Contract Deployment ******* */
  // const factory = await ethers.deployContract("MultiSigFactory");


  // await factory.waitForDeployment();
  // console.log("MultiSig Factory deployed at:", await factory.getAddress());



  /* ******* MultiSignature Contract Deployment ******* */

  const deployer = "0x";
  const _maxOwnersLimit = 20;
  const _threshold = 3;
  const _dailyLimit = '5000000000000000000';
  const owners = ["0x", "0x"]

  // const MultiSig = await ethers.deployContract("MultiSigWallet", [
  //   deployer,
  //   _maxOwnersLimit,
  //   _threshold,
  //   _dailyLimit,
  //   owners
  // ]);


  // await MultiSig.waitForDeployment();
  // console.log("MultiSig deployed at:", await MultiSig.getAddress());

  /* ******* Contract Verification ******* */

  await hre.run("verify:verify", {
    address: "0x",
    constructorArguments: [ deployer,
      _maxOwnersLimit,
      _threshold,
      _dailyLimit,
      owners],
  })

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
