require("@nomicfoundation/hardhat-toolbox");

require("dotenv").config();

module.exports = {
  etherscan: {
    apiKey: "AYBZ53EN445WNPFP2IZ85RXRPB4FH5XBP7",
  },
  networks: {
    hardhat: {},
    bscTest: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      accounts: {
        mnemonic: process.env.MNEMONIC || "",
      },
    },
    sepolia: {
      url: "https://virulent-billowing-pallet.ethereum-sepolia.quiknode.pro/3023995be639d61d67feb591f780ac73049f92f9/",
      chainId: 11155111,
      accounts: {
        mnemonic: process.env.MNEMONIC || "",
      },
    },
  },
  solidity: "0.8.18",
};