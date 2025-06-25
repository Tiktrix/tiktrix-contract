import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";

const sourcePath = process.env.SOURCE_PATH || "./contract";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  paths: {
    sources: sourcePath,
    artifacts: "./artifacts",
    cache: "./cache",
    tests: "./test"
  }
};

export default config;
