const Migrations = artifacts.require("AdAnimalNFT");
const ethers = require("ethers");

module.exports = function (deployer) {
  deployer.deploy(
    Migrations, 
    'TestADA', // Name
    'TADA', // Symbol
    'https://adanimals.art/', // BaseTokenURI
    ethers.utils.parseUnits('0.0001'), // 0.01 BNB mint Price
    50, // max mint
    '0x34c935743ddEaCbd6675d2705e4A55992eB99F82', // admin address
    6, // total RarityType
    1000, //10% Reward fee
    '0x405eC1cbCb4147d9ce25b97568A2151245FCe447',
    1634758937,
    ethers.utils.parseUnits('100') // 100 NCT (Name Change Price)
  );
};
