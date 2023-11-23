import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1_000_000_000,
      },
    },
  },
  paths: {
    tests: "./test/ethers",
  },
  typechain: {
    outDir: "typechain",
  },
};

export default config;
