// Local/dev deployment for TrixStaking.
//
// Usage (local anvil-monad):
//   SOURCE_PATH=./contract/tiktrix-staking \
//   STAKING_ADMIN=0x... TRIX_TOKEN=0x... \
//   npx hardhat run scripts/deploy-staking.ts --network <network>
//
// Optional env: STAKING_APR_BPS (default 300 = 3.00%),
//   STAKING_MIN_STAKE (default 1000 TRIX), STAKING_DELAY_SEC (default 86400),
//   STAKING_CONTRACT_URI
// Production publishing uses the existing flow:
//   npm run contract ./contract/tiktrix-staking
import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  const admin = process.env.STAKING_ADMIN ?? deployer.address;
  const trixToken = process.env.TRIX_TOKEN;
  if (!trixToken) throw new Error("TRIX_TOKEN env is required");

  const aprBps = BigInt(process.env.STAKING_APR_BPS ?? "300");
  const minStake = ethers.parseEther(process.env.STAKING_MIN_STAKE ?? "1000");
  const delaySec = BigInt(process.env.STAKING_DELAY_SEC ?? "86400");
  const contractURI = process.env.STAKING_CONTRACT_URI ?? "";

  const factory = await ethers.getContractFactory("TrixStaking");
  const staking = await factory.deploy(
    admin,
    trixToken,
    aprBps,
    minStake,
    delaySec,
    contractURI
  );
  await staking.waitForDeployment();

  console.log(
    JSON.stringify(
      {
        contract: "TrixStaking",
        address: await staking.getAddress(),
        admin,
        trixToken,
        aprBps: aprBps.toString(),
        minStake: minStake.toString(),
        withdrawalDelaySec: delaySec.toString(),
      },
      null,
      2
    )
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
