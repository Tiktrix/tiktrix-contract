// End-to-end scenario for TrixStaking against a live local node.
//
//   1) SOURCE_PATH=./contract/tiktrix-staking npx hardhat node --port 8546
//   2) SOURCE_PATH=./contract/tiktrix-staking \
//      npx hardhat run scripts/e2e-staking-localnet.ts --network localnet
//
// Deploys a fresh TRIX test token + TrixStaking, then walks through the full
// user flow with time travel (evm_increaseTime), asserting at every step.
import { ethers } from "hardhat";

const MIN_STAKE = ethers.parseEther("1000");
const YEAR = 31536000;
const DAY = 86400;

function fmt(v: bigint) {
  return `${ethers.formatEther(v)} TRIX`;
}

async function travel(seconds: number) {
  await ethers.provider.send("evm_increaseTime", [seconds]);
  await ethers.provider.send("evm_mine", []);
}

async function expectRevert(p: Promise<unknown>, label: string, reason: string) {
  try {
    await p;
    throw new Error(`EXPECTED REVERT BUT SUCCEEDED: ${label}`);
  } catch (e: any) {
    if (!String(e.message).includes(reason)) throw e;
    console.log(`  ✔ ${label} → reverted with "${reason}"`);
  }
}

function assertClose(actual: bigint, expected: bigint, tolerance: bigint, label: string) {
  const diff = actual > expected ? actual - expected : expected - actual;
  if (diff > tolerance) {
    throw new Error(`ASSERT FAIL ${label}: expected ~${fmt(expected)}, got ${fmt(actual)}`);
  }
  console.log(`  ✔ ${label}: ${fmt(actual)} (expected ~${fmt(expected)})`);
}

async function main() {
  const [admin, user] = await ethers.getSigners();
  console.log(`\n[1] 배포 — admin=${admin.address}\n    user =${user.address}`);

  const tokenFactory = await ethers.getContractFactory(
    "contract/tiktrix-main-token/TrixToken.sol:TrixToken"
  );
  const trix = await tokenFactory.deploy("Test Trix", "tTRIX", 1_000_000_000n, "ipfs://test");
  await trix.waitForDeployment();
  console.log(`    tTRIX  = ${await trix.getAddress()}`);

  const stakingFactory = await ethers.getContractFactory("TrixStaking");
  const staking = await stakingFactory.deploy(
    admin.address, await trix.getAddress(), 300, MIN_STAKE, DAY, "ipfs://staking"
  );
  await staking.waitForDeployment();
  const stakingAddr = await staking.getAddress();
  console.log(`    TrixStaking = ${stakingAddr} (APR 3.00%, min 1000, delay 24h)`);

  await (await trix.transfer(user.address, ethers.parseEther("5000"))).wait();
  await (await trix.connect(user).approve(stakingAddr, ethers.MaxUint256)).wait();
  await (await trix.approve(stakingAddr, ethers.MaxUint256)).wait();

  console.log("\n[2] 최소 예치 규칙");
  await expectRevert(
    staking.connect(user).stake(ethers.parseEther("999")),
    "999 TRIX 예치", "Below minimum stake"
  );
  await (await staking.connect(user).stake(MIN_STAKE)).wait();
  console.log(`  ✔ 1000 TRIX 예치 성공 (totalStaked=${fmt(await staking.totalStaked())})`);

  console.log("\n[3] 1년 경과 → 고정 3% 적립");
  await travel(YEAR);
  assertClose(
    await staking.earned(user.address),
    ethers.parseEther("30"), ethers.parseEther("0.01"),
    "1년 후 earned"
  );

  console.log("\n[4] 출금 요청 (24h 지연 + 적립 중단)");
  await expectRevert(
    staking.connect(user).requestWithdraw(ethers.parseEther("100")),
    "잔여 900 남기는 요청", "Remainder below minimum stake"
  );
  await (await staking.connect(user).requestWithdraw(MIN_STAKE)).wait();
  const earnedAtRequest = await staking.earned(user.address);
  console.log(`  ✔ 전액 출금 요청 접수 (earned 고정: ${fmt(earnedAtRequest)})`);

  await expectRevert(staking.connect(user).withdraw(), "즉시 출금 시도", "No withdrawable amount");
  await travel(DAY / 2);
  await expectRevert(staking.connect(user).withdraw(), "12시간 후 출금 시도", "No withdrawable amount");

  await travel(YEAR); // 대기 중 적립 중단 검증 겸 충분히 경과
  const earnedAfterWait = await staking.earned(user.address);
  if (earnedAfterWait !== earnedAtRequest) throw new Error("대기 중 리워드가 적립되었음!");
  console.log("  ✔ 대기 기간 동안 리워드 적립 없음");

  console.log("\n[5] 24h 경과 후 원금 출금");
  const balBefore = await trix.balanceOf(user.address);
  await (await staking.connect(user).withdraw()).wait();
  assertClose(
    (await trix.balanceOf(user.address)) - balBefore,
    MIN_STAKE, 0n, "출금 수령액"
  );

  console.log("\n[6] 리워드 청구 (풀 충전 전/후)");
  await expectRevert(staking.connect(user).claimReward(), "풀 충전 전 청구", "Insufficient reward pool");
  await (await staking.depositReward(ethers.parseEther("100"))).wait();
  console.log(`  ✔ admin이 리워드 풀 100 TRIX 충전`);

  const balBeforeClaim = await trix.balanceOf(user.address);
  await (await staking.connect(user).claimReward()).wait();
  assertClose(
    (await trix.balanceOf(user.address)) - balBeforeClaim,
    earnedAtRequest, ethers.parseEther("0.001"), "청구 수령액"
  );

  console.log("\n[7] 최종 상태");
  const info = await staking.getStakeInfo(user.address);
  console.log(`    예치=${fmt(info[0])}, 대기=${fmt(info[1])}, 출금가능=${fmt(info[2])}, earned=${fmt(info[3])}`);
  console.log(`    유저 잔액=${fmt(await trix.balanceOf(user.address))} (시작 5000 + 리워드 ~30)`);
  console.log(`    잔여 리워드 풀=${fmt(await staking.availableRewardBalance())}`);

  console.log("\n✅ E2E 시나리오 전체 통과\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
