// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const ethers = hre.ethers

async function main() {

  const [dc] = await ethers.getSigners();

  console.log('deployer::::', dc.address)

  const deployer = "0x82237B1609768744789aA6C17d8E29fA472F081d";
  const owner = ["0x82237B1609768744789aA6C17d8E29fA472F081d", "0xd06808E845178238BfbEE9AD186734FD8e6D6C69", 
  "0x0680141104B05A4da862747fBebc205064Df06c5"]
  const required = '2';
  const limit = '2000000000000000000';


  // // const factory = await ethers.deployContract("MultiSigFactory");
  // const MultiSig = await ethers.deployContract("MultiSigWallet", [
  //   deployer,
  //   owner,
  //   required,
  //   limit
  // ]);


  // await MultiSig.waitForDeployment();

  // console.log("MultiSig deployed at:", await MultiSig.getAddress());

  await hre.run("verify:verify", {
    address: "0x85C45193553A1d03B32665b34EEC61c1b26Cb390",
    constructorArguments: [ deployer,
        owner,
        required,
        limit],
  })

}

//   console.log(
//     `Lock with ${ethers.formatEther(w
//       lockedAmount
//     )}ETH and unlock timestamp ${unlockTime} deployed to ${lock.target}`
//   );
// }

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
