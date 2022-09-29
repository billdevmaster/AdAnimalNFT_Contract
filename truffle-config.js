const HDWalletProvider = require('@truffle/hdwallet-provider');
const fs = require('fs');
require('dotenv').config();
const mnemonic = process.env.mnemonic;

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 8545,            // Standard BSC port (default: none)
      network_id: "*",       // Any network (default: none)
    },
    bsctestnet: {
      provider: () => new HDWalletProvider(mnemonic, `https://data-seed-prebsc-1-s1.binance.org:8545`),
      network_id: 97,
      confirmations: 5,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    bsc: {
      provider: () => new HDWalletProvider(mnemonic, `https://bsc-dataseed1.binance.org`),
      network_id: 56,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    eth: {
      provider: () => new HDWalletProvider(mnemonic, `https://mainnet.infura.io/v3/724ed30518db4eb286dbd0a51011f824`),
      network_id: 1,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    polygon: {
      provider: () => new HDWalletProvider(mnemonic, `https://rpc-mainnet.maticvigil.com/v1/b89438763cc1b513c5d0b9f743baf7e4abfb7157`),
      network_id: 137,
      confirmations: 5,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    rinkeby: {
      provider: () => new HDWalletProvider(mnemonic, `https://rinkeby.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161`),
      network_id: 4,
    },
    goerli: {
      provider: () => new HDWalletProvider(mnemonic, `https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161`),
      network_id: 5,
    },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "^0.8.0", // A version or constraint - Ex. "^0.5.0"
      settings: {
        optimizer: {
          enabled: true,
          runs: 20   // Optimize for how many times you intend to run the code
        },
      },
    },
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    // bscscan: 'QC4UPPIN4JPDA4YAY1PAS46RGNJUYFHKCM',
    // polygonscan: 'X1RVAXVNZFIXVMYUGS8DW8MR8NUZM5VA58'
    // bsctestscan: 'NPIT4183DK8BMGVZDT9C4R14S1QMEHIT88',
    etherscan: 'QNH5TIIYA5GXN2TT326FFBMSSY3H5B24XX'
  },
}