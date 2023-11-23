import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-foundry';
import '@nomicfoundation/hardhat-toolbox';

const config: HardhatUserConfig = {
  solidity: '0.8.22',
  paths: {
    tests: './test/ethers',
  },
  typechain: {
    outDir: 'typechain',
  },
};

export default config;
