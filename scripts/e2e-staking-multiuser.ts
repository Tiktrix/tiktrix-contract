// Multi-user end-to-end scenario for TrixStaking (in-process hardhat network).
//
//   SOURCE_PATH=./contract/tiktrix-staking \
//   npx hardhat run scripts/e2e-staking-multiuser.ts
//
// 3 users (alice/bob/carol) walk through stake -> accrue -> requestWithdraw
// -> cancel -> withdraw -> claim, asserting per-user isolation and the
// global bookkeeping (totalStaked / totalPendingWithdrawal) at every step.
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

function assertEq(actual: bigint, expected: bigint, label: string) {
  if (actual !== expected) {
    throw new Error(`ASSERT FAIL ${label}: expected ${fmt(expected)}, got ${fmt(actual)}`);
  }
  console.log(`  ✔ ${label}: ${fmt(actual)}`);
}

function assertClose(actual: bigint, expected: bigint, tolerance: bigint, label: string) {
  const diff = actual > expected ? actual - expected : expected - actual;
  if (diff > tolerance) {
    throw new Error(`ASSERT FAIL ${label}: expected ~${fmt(expected)}, got ${fmt(actual)}`);
  }
  console.log(`  ✔ ${label}: ${fmt(actual)} (expected ~${fmt(expected)})`);
}

// 30일 고정 3% 적립 기대값: amount * 300/10000 * elapsed / YEAR
function expectedReward(amount: bigint, elapsedSec: number): bigint {
  return (amount * 300n * BigInt(elapsedSec)) / 10000n / BigInt(YEAR);
}

async function main() {
  const [admin, alice, bob, carol] = await ethers.getSigners();
  console.log(`\n[1] 배포 및 자금 분배`);
  console.log(`    admin=${admin.address}`);
  console.log(`    alice=${alice.address}\n    bob  =${bob.address}\n    carol=${carol.address}`);

  const tokenFactory = await ethers.getContractFactory(
    "contract/tiktrix-main-token/TrixToken.sol:TrixToken"
  );
  const trix = await tokenFactory.deploy("Test Trix", "tTRIX", 1_000_000_000n, "ipfs://test");
  await trix.waitForDeployment();

  const stakingFactory = await ethers.getContractFactory("TrixStaking");
  const staking = await stakingFactory.deploy(
    admin.address, await trix.getAddress(), 300, MIN_STAKE, DAY, "ipfs://staking"
  );
  await staking.waitForDeployment();
  const stakingAddr = await staking.getAddress();
  console.log(`    TrixStaking = ${stakingAddr} (APR 3.00%, min 1000, delay 24h)`);

  for (const [signer, amount] of [
    [alice, "10000"],
    [bob, "3000"],
    [carol, "1500"],
  ] as const) {
    await (await trix.transfer(signer.address, ethers.parseEther(amount))).wait();
    await (await trix.connect(signer).approve(stakingAddr, ethers.MaxUint256)).wait();
  }
  await (await trix.approve(stakingAddr, ethers.MaxUint256)).wait();

  console.log("\n[2] 예치 — 최소 예치 규칙 (유저별)");
  await expectRevert(
    staking.connect(carol).stake(ethers.parseEther("999")),
    "carol 999 TRIX 예치", "Below minimum stake"
  );
  await (await staking.connect(alice).stake(ethers.parseEther("5000"))).wait();
  await (await staking.connect(bob).stake(MIN_STAKE)).wait(); // 경계값 1000
  await (await staking.connect(carol).stake(ethers.parseEther("1500"))).wait();
  assertEq(await staking.totalStaked(), ethers.parseEther("7500"), "totalStaked");

  console.log("\n[3] 30일 경과 — 유저별 지분 무관 고정 3% 독립 적립");
  await travel(30 * DAY);
  assertClose(await staking.earned(alice.address), expectedReward(ethers.parseEther("5000"), 30 * DAY), ethers.parseEther("0.01"), "alice earned (30d)");
  assertClose(await staking.earned(bob.address), expectedReward(ethers.parseEther("1000"), 30 * DAY), ethers.parseEther("0.01"), "bob earned (30d)");
  assertClose(await staking.earned(carol.address), expectedReward(ethers.parseEther("1500"), 30 * DAY), ethers.parseEther("0.01"), "carol earned (30d)");

  console.log("\n[4] 출금 요청 — 잔여 규칙 & 유저 간 격리");
  // alice: 잔여 1 남기는 요청 → revert
  await expectRevert(
    staking.connect(alice).requestWithdraw(ethers.parseEther("4999")),
    "alice 잔여 1 요청", "Remainder below minimum stake"
  );
  // alice: 2000 요청 두 번 (잔여 3000 → 1000, 모두 유효)
  await (await staking.connect(alice).requestWithdraw(ethers.parseEther("2000"))).wait();
  await (await staking.connect(alice).requestWithdraw(ethers.parseEther("2000"))).wait();
  // bob: 전액 요청 (잔여 0 허용)
  await (await staking.connect(bob).requestWithdraw(MIN_STAKE)).wait();
  // carol: 500 요청 (잔여 1000)
  await (await staking.connect(carol).requestWithdraw(ethers.parseEther("500"))).wait();

  assertEq(await staking.totalStaked(), ethers.parseEther("2000"), "totalStaked (요청 후)");
  assertEq(await staking.totalPendingWithdrawal(), ethers.parseEther("5500"), "totalPendingWithdrawal");

  // bob의 요청이 alice 포지션에 영향 없는지
  const aliceInfo = await staking.getStakeInfo(alice.address);
  assertEq(aliceInfo[0], ethers.parseEther("1000"), "alice 잔여 예치");
  assertEq(aliceInfo[1], ethers.parseEther("4000"), "alice 출금대기");

  console.log("\n[5] 출금 요청 취소 — alice 두 번째 요청(2000) 재예치");
  const aliceRequests = await staking.getWithdrawalRequests(alice.address);
  const secondRequestId = aliceRequests[1].id;
  await (await staking.connect(alice).cancelWithdrawalRequest(secondRequestId)).wait();
  assertEq((await staking.getStakeInfo(alice.address))[0], ethers.parseEther("3000"), "alice 취소 후 예치");
  assertEq(await staking.totalPendingWithdrawal(), ethers.parseEther("3500"), "totalPendingWithdrawal (취소 후)");
  // 타인 요청 취소 시도
  const bobRequests = await staking.getWithdrawalRequests(bob.address);
  await expectRevert(
    staking.connect(alice).cancelWithdrawalRequest(bobRequests[0].id),
    "alice가 bob 요청 취소 시도", "Request not found"
  );

  console.log("\n[6] 24h 미경과 출금 차단 → 경과 후 일괄 출금");
  await expectRevert(staking.connect(bob).withdraw(), "bob 12h 전 출금", "No withdrawable amount");
  await travel(DAY + 60);

  const earnedAliceAtWithdraw = await staking.earned(alice.address);
  for (const [signer, name, expectedAmount] of [
    [alice, "alice", ethers.parseEther("2000")],
    [bob, "bob", ethers.parseEther("1000")],
    [carol, "carol", ethers.parseEther("500")],
  ] as const) {
    const before = await trix.balanceOf(signer.address);
    await (await staking.connect(signer).withdraw()).wait();
    assertEq((await trix.balanceOf(signer.address)) - before, expectedAmount, `${name} 출금 수령`);
  }
  assertEq(await staking.totalPendingWithdrawal(), 0n, "totalPendingWithdrawal (출금 완료)");

  console.log("\n[7] 대기분 무적립 + 잔여 예치분 계속 적립 검증");
  // bob: 전액 출금했으므로 요청 시점 이후 earned 고정이어야 함
  const bobEarned = await staking.earned(bob.address);
  assertClose(bobEarned, expectedReward(MIN_STAKE, 30 * DAY), ethers.parseEther("0.01"), "bob earned 고정 (요청 후 24h 무적립)");
  // alice: 3000이 계속 적립 중 (요청 시점 이후 1일 추가)
  const aliceExpected =
    expectedReward(ethers.parseEther("5000"), 30 * DAY) + // 30일간 5000
    expectedReward(ethers.parseEther("3000"), DAY + 60);  // 이후 1일간 3000 (취소 재예치 포함)
  assertClose(earnedAliceAtWithdraw, aliceExpected, ethers.parseEther("0.05"), "alice earned (계속 적립)");

  console.log("\n[8] 리워드 풀 충전 및 전원 청구");
  await expectRevert(staking.connect(bob).claimReward(), "풀 충전 전 청구", "Insufficient reward pool");
  await (await staking.depositReward(ethers.parseEther("100"))).wait();

  for (const [signer, name] of [
    [alice, "alice"],
    [bob, "bob"],
    [carol, "carol"],
  ] as const) {
    const earned = await staking.earned(signer.address);
    const before = await trix.balanceOf(signer.address);
    await (await staking.connect(signer).claimReward()).wait();
    assertClose((await trix.balanceOf(signer.address)) - before, earned, ethers.parseEther("0.001"), `${name} 리워드 수령`);
  }

  console.log("\n[9] 최종 상태");
  console.log(`    totalStaked=${fmt(await staking.totalStaked())} (alice 3000 + carol 1000)`);
  console.log(`    잔여 리워드 풀=${fmt(await staking.availableRewardBalance())}`);
  console.log(`    rewardDeficit=${fmt(await staking.rewardDeficit())}`);
  assertEq(await staking.totalStaked(), ethers.parseEther("4000"), "최종 totalStaked");

  // 컨트랙트 잔액 무결성: 잔액 == 예치원금 + 대기 + 잔여풀 + 미청구적립
  const balance = await trix.balanceOf(stakingAddr);
  const owed =
    (await staking.totalStaked()) +
    (await staking.totalPendingWithdrawal()) +
    (await staking.availableRewardBalance());
  // 미청구 적립분(전원 청구 완료 후 잔여 예치분의 청구 후 초 단위 적립)만큼 오차 허용
  assertClose(balance, owed, ethers.parseEther("0.01"), "컨트랙트 잔액 무결성");

  console.log("\n✅ 멀티유저 E2E 시나리오 전체 통과\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
