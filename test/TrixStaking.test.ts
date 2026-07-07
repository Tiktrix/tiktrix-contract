import { expect } from "chai";
import { ethers } from "hardhat";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const APR_BPS = 300n; // 3.00%
const MIN_STAKE = ethers.parseEther("1000");
const WITHDRAWAL_DELAY = 86400n; // 24h
const YEAR = 31536000n;

describe("TrixStaking", () => {
  async function deployFixture() {
    const [admin, user1, user2, outsider] = await ethers.getSigners();

    const tokenFactory = await ethers.getContractFactory(
      "contract/tiktrix-main-token/TrixToken.sol:TrixToken"
    );
    const trix = await tokenFactory
      .connect(admin)
      .deploy("Tiktrix Token", "TRIX", 1_000_000_000n, "ipfs://trix");

    const stakingFactory = await ethers.getContractFactory("TrixStaking");
    const staking = await stakingFactory.deploy(
      admin.address,
      await trix.getAddress(),
      APR_BPS,
      MIN_STAKE,
      WITHDRAWAL_DELAY,
      "ipfs://trix-staking"
    );

    const stakingAddress = await staking.getAddress();
    for (const user of [user1, user2]) {
      await trix.connect(admin).transfer(user.address, ethers.parseEther("100000"));
      await trix.connect(user).approve(stakingAddress, ethers.MaxUint256);
    }
    await trix.connect(admin).approve(stakingAddress, ethers.MaxUint256);

    return { trix, staking, stakingAddress, admin, user1, user2, outsider };
  }

  describe("deployment", () => {
    it("sets initial parameters", async () => {
      const { staking } = await loadFixture(deployFixture);
      expect(await staking.aprBps()).to.equal(APR_BPS);
      expect(await staking.minStakeAmount()).to.equal(MIN_STAKE);
      expect(await staking.withdrawalDelay()).to.equal(WITHDRAWAL_DELAY);
      expect(await staking.stakingPaused()).to.equal(false);
    });
  });

  describe("stake", () => {
    it("rejects a first stake below the minimum", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await expect(
        staking.connect(user1).stake(MIN_STAKE - 1n)
      ).to.be.revertedWith("Below minimum stake");
    });

    it("rejects zero amount", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await expect(staking.connect(user1).stake(0)).to.be.revertedWith(
        "Must stake non-zero amount"
      );
    });

    it("accepts the exact minimum and small top-ups afterwards", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await expect(staking.connect(user1).stake(MIN_STAKE))
        .to.emit(staking, "Staked")
        .withArgs(user1.address, MIN_STAKE, MIN_STAKE);

      const topUp = ethers.parseEther("1");
      await staking.connect(user1).stake(topUp);
      expect((await staking.stakers(user1.address)).stakedAmount).to.equal(
        MIN_STAKE + topUp
      );
      expect(await staking.totalStaked()).to.equal(MIN_STAKE + topUp);
    });

    it("moves tokens into the contract", async () => {
      const { staking, stakingAddress, trix, user1 } =
        await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);
      expect(await trix.balanceOf(stakingAddress)).to.equal(MIN_STAKE);
    });
  });

  describe("reward accrual (fixed APR)", () => {
    it("accrues exactly 3% over one year", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);

      await time.increase(YEAR);
      // 1000 * 3% = 30 TRIX
      expect(await staking.earned(user1.address)).to.be.closeTo(
        ethers.parseEther("30"),
        ethers.parseEther("0.001")
      );
    });

    it("is independent of other stakers (no pool dilution)", async () => {
      const { staking, user1, user2 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);
      await staking.connect(user2).stake(ethers.parseEther("50000"));

      await time.increase(YEAR);
      expect(await staking.earned(user1.address)).to.be.closeTo(
        ethers.parseEther("30"),
        ethers.parseEther("0.001")
      );
    });

    it("applies an APR change only from the change onwards", async () => {
      const { staking, admin, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);

      await time.increase(YEAR / 2n);
      await expect(staking.connect(admin).setApr(600))
        .to.emit(staking, "AprUpdated")
        .withArgs(APR_BPS, 600);
      await time.increase(YEAR / 2n);

      // half year at 3% (15) + half year at 6% (30) = 45
      expect(await staking.earned(user1.address)).to.be.closeTo(
        ethers.parseEther("45"),
        ethers.parseEther("0.001")
      );
    });

    it("rejects APR above 100% and non-admin callers", async () => {
      const { staking, admin, user1 } = await loadFixture(deployFixture);
      await expect(staking.connect(admin).setApr(10001)).to.be.revertedWith(
        "APR too high"
      );
      await expect(staking.connect(user1).setApr(500)).to.be.reverted;
    });
  });

  describe("requestWithdraw", () => {
    it("enforces the remainder rule (0 or >= minimum)", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(ethers.parseEther("1500"));

      await expect(
        staking.connect(user1).requestWithdraw(ethers.parseEther("600"))
      ).to.be.revertedWith("Remainder below minimum stake");

      await staking.connect(user1).requestWithdraw(ethers.parseEther("500")); // remainder 1000
      await staking.connect(user1).requestWithdraw(ethers.parseEther("1000")); // remainder 0
    });

    it("records the request with id and release time", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);

      const tx = await staking.connect(user1).requestWithdraw(MIN_STAKE);
      const timestamp = BigInt(await time.latest());
      await expect(tx)
        .to.emit(staking, "WithdrawalRequested")
        .withArgs(user1.address, 1, MIN_STAKE, timestamp + WITHDRAWAL_DELAY);

      const requests = await staking.getWithdrawalRequests(user1.address);
      expect(requests.length).to.equal(1);
      expect(requests[0].amount).to.equal(MIN_STAKE);
      expect(await staking.totalStaked()).to.equal(0);
      expect(await staking.totalPendingWithdrawal()).to.equal(MIN_STAKE);
    });

    it("stops reward accrual for the requested amount", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);
      await staking.connect(user1).requestWithdraw(MIN_STAKE);

      const earnedAtRequest = await staking.earned(user1.address);
      await time.increase(YEAR);
      expect(await staking.earned(user1.address)).to.equal(earnedAtRequest);
    });

    it("caps open requests at the maximum", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(ethers.parseEther("100000"));
      for (let i = 0; i < 10; i++) {
        await staking.connect(user1).requestWithdraw(ethers.parseEther("1000"));
      }
      await expect(
        staking.connect(user1).requestWithdraw(ethers.parseEther("1000"))
      ).to.be.revertedWith("Too many open requests");
    });
  });

  describe("withdraw", () => {
    it("rejects before the 24h delay", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);
      await staking.connect(user1).requestWithdraw(MIN_STAKE);

      await expect(staking.connect(user1).withdraw()).to.be.revertedWith(
        "No withdrawable amount"
      );
      await time.increase(WITHDRAWAL_DELAY - 10n);
      await expect(staking.connect(user1).withdraw()).to.be.revertedWith(
        "No withdrawable amount"
      );
    });

    it("pays out matured requests after the delay", async () => {
      const { staking, trix, user1 } = await loadFixture(deployFixture);
      const before = await trix.balanceOf(user1.address);
      await staking.connect(user1).stake(MIN_STAKE);
      await staking.connect(user1).requestWithdraw(MIN_STAKE);

      await time.increase(WITHDRAWAL_DELAY);
      await expect(staking.connect(user1).withdraw())
        .to.emit(staking, "Withdrawn")
        .withArgs(user1.address, 1, MIN_STAKE);

      expect(await trix.balanceOf(user1.address)).to.equal(before);
      expect(await staking.totalPendingWithdrawal()).to.equal(0);
      expect(
        (await staking.getWithdrawalRequests(user1.address)).length
      ).to.equal(0);
    });

    it("pays only matured requests when some are still pending", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(ethers.parseEther("3000"));
      await staking.connect(user1).requestWithdraw(ethers.parseEther("1000"));

      await time.increase(WITHDRAWAL_DELAY / 2n);
      await staking.connect(user1).requestWithdraw(ethers.parseEther("1000"));

      await time.increase(WITHDRAWAL_DELAY / 2n);
      await staking.connect(user1).withdraw();

      const remaining = await staking.getWithdrawalRequests(user1.address);
      expect(remaining.length).to.equal(1);
      expect(remaining[0].id).to.equal(2);
      expect(await staking.totalPendingWithdrawal()).to.equal(
        ethers.parseEther("1000")
      );
    });
  });

  describe("cancelWithdrawalRequest", () => {
    it("re-stakes the requested amount", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);
      await staking.connect(user1).requestWithdraw(MIN_STAKE);

      await expect(staking.connect(user1).cancelWithdrawalRequest(1))
        .to.emit(staking, "WithdrawalCancelled")
        .withArgs(user1.address, 1, MIN_STAKE);

      expect((await staking.stakers(user1.address)).stakedAmount).to.equal(
        MIN_STAKE
      );
      expect(await staking.totalPendingWithdrawal()).to.equal(0);
    });

    it("rejects a cancel that would recreate a below-minimum position", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(ethers.parseEther("2000"));
      await staking.connect(user1).requestWithdraw(ethers.parseEther("500")); // id 1
      await staking.connect(user1).requestWithdraw(ethers.parseEther("1500")); // id 2, position 0

      await expect(
        staking.connect(user1).cancelWithdrawalRequest(1)
      ).to.be.revertedWith("Below minimum stake");
      await staking.connect(user1).cancelWithdrawalRequest(2); // 1500 >= min
    });

    it("rejects unknown request ids", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await expect(
        staking.connect(user1).cancelWithdrawalRequest(99)
      ).to.be.revertedWith("Request not found");
    });
  });

  describe("claimReward", () => {
    it("never pays rewards out of staked principal", async () => {
      const { staking, user1, user2 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);
      await staking.connect(user2).stake(ethers.parseEther("50000"));

      await time.increase(YEAR);
      // Contract holds 51000 TRIX of principal but the reward pool is empty.
      await expect(staking.connect(user1).claimReward()).to.be.revertedWith(
        "Insufficient reward pool"
      );
    });

    it("pays from the reward pool and resets the accrual", async () => {
      const { staking, trix, admin, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);
      await staking.connect(admin).depositReward(ethers.parseEther("100"));

      await time.increase(YEAR);
      const before = await trix.balanceOf(user1.address);
      await expect(staking.connect(user1).claimReward()).to.emit(
        staking,
        "RewardClaimed"
      );

      const paid = (await trix.balanceOf(user1.address)) - before;
      expect(paid).to.be.closeTo(
        ethers.parseEther("30"),
        ethers.parseEther("0.001")
      );
      // Accrual restarts from zero (only a ~1s sliver remains right after claim).
      expect(await staking.earned(user1.address)).to.be.lt(
        ethers.parseEther("0.00001")
      );
    });

    it("rejects a claim when nothing is staked and nothing accrued", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await expect(staking.connect(user1).claimReward()).to.be.revertedWith(
        "No reward to claim"
      );
    });
  });

  describe("admin", () => {
    it("recoverExcessReward is capped to the unowed reward pool", async () => {
      const { staking, admin, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);
      await staking.connect(admin).depositReward(ethers.parseEther("100"));

      await expect(
        staking.connect(admin).recoverExcessReward(ethers.parseEther("101"))
      ).to.be.revertedWith("Exceeds available");
      await staking.connect(admin).recoverExcessReward(ethers.parseEther("100"));

      // Principal is untouchable even with an empty reward pool.
      expect(await staking.availableRewardBalance()).to.equal(0);
    });

    it("recoverERC20 rejects the staking token", async () => {
      const { staking, trix, admin } = await loadFixture(deployFixture);
      await expect(
        staking.connect(admin).recoverERC20(await trix.getAddress(), 1)
      ).to.be.revertedWith("Cannot recover staking token");
    });

    it("updates minimum stake and withdrawal delay within bounds", async () => {
      const { staking, admin } = await loadFixture(deployFixture);
      await expect(
        staking.connect(admin).setMinStakeAmount(ethers.parseEther("500"))
      )
        .to.emit(staking, "MinStakeAmountUpdated")
        .withArgs(MIN_STAKE, ethers.parseEther("500"));

      await expect(
        staking.connect(admin).setWithdrawalDelay(31 * 86400)
      ).to.be.revertedWith("Delay too long");
      await staking.connect(admin).setWithdrawalDelay(48 * 3600);
      expect(await staking.withdrawalDelay()).to.equal(48 * 3600);
    });

    it("non-admin cannot call admin functions", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await expect(staking.connect(user1).setMinStakeAmount(0)).to.be.reverted;
      await expect(staking.connect(user1).setStakingPaused(true)).to.be
        .reverted;
      await expect(staking.connect(user1).recoverExcessReward(1)).to.be
        .reverted;
    });
  });

  describe("reward pool deficit (audit finding #1)", () => {
    it("availableRewardBalance saturates to 0 instead of reverting in deficit", async () => {
      const { staking, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);
      await time.increase(YEAR);
      // Checkpoint the accrual with an unfunded pool -> deficit state.
      await staking.connect(user1).requestWithdraw(MIN_STAKE);

      expect(await staking.availableRewardBalance()).to.equal(0);
      expect(await staking.rewardDeficit()).to.be.closeTo(
        ethers.parseEther("30"),
        ethers.parseEther("0.001")
      );
    });

    it("recoverExcessReward stays safely blocked during deficit", async () => {
      const { staking, admin, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);
      await time.increase(YEAR);
      await staking.connect(user1).requestWithdraw(MIN_STAKE);

      await expect(
        staking.connect(admin).recoverExcessReward(1)
      ).to.be.revertedWith("Exceeds available");
    });

    it("funding the pool clears the deficit and restores claims", async () => {
      const { staking, admin, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);
      await time.increase(YEAR);
      await staking.connect(user1).requestWithdraw(MIN_STAKE);

      await staking.connect(admin).depositReward(ethers.parseEther("100"));
      expect(await staking.rewardDeficit()).to.equal(0);
      expect(await staking.availableRewardBalance()).to.be.closeTo(
        ethers.parseEther("70"),
        ethers.parseEther("0.001")
      );
      await staking.connect(user1).claimReward();
    });
  });

  describe("pause", () => {
    it("blocks staking but keeps every exit path open", async () => {
      const { staking, admin, user1 } = await loadFixture(deployFixture);
      await staking.connect(user1).stake(MIN_STAKE);
      await staking.connect(admin).depositReward(ethers.parseEther("100"));
      await time.increase(YEAR);

      await staking.connect(admin).setStakingPaused(true);
      await expect(
        staking.connect(user1).stake(MIN_STAKE)
      ).to.be.revertedWith("Staking is paused");

      // Exits and claims still work while paused.
      await staking.connect(user1).claimReward();
      await staking.connect(user1).requestWithdraw(MIN_STAKE);
      await time.increase(WITHDRAWAL_DELAY);
      await staking.connect(user1).withdraw();
      expect((await staking.stakers(user1.address)).stakedAmount).to.equal(0);
    });
  });
});
