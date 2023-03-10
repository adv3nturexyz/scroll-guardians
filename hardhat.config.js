require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();
require("@nomiclabs/hardhat-etherscan");

module.exports = {
  solidity: '0.8.17',
  networks: {
    scrollAlpha: {
      url: `https://alpha-rpc.scroll.io/l2`,
      accounts: [process.env.PRIVATE_KEY],
    },
    goerli: {
      url: `https://boldest-aged-energy.ethereum-goerli.discover.quiknode.pro/${process.env.QUICKNODE_GOERLI_API}`,
      accounts: [process.env.PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_KEY,
  }
};