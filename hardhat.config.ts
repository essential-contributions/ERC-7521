import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-foundry';
import '@nomicfoundation/hardhat-toolbox';

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.24',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1_000_000_000,
      },
      viaIR: true,
    },
  },
  paths: {
    tests: './test/ethers',
  },
  typechain: {
    outDir: 'typechain',
  },
};

export default config;
