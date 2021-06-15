const { expect } = require('chai');
const { ethers } = require('hardhat');
const { time } = require('@openzeppelin/test-helpers');

describe('TokenVesting', function() {
  let tokenVesting;
  let zestyToken;
  let signers;
  let provider;

  beforeEach(async () => {
    signers = await ethers.getSigners();
    provider = signers[0].provider;

    const ZestyToken = await ethers.getContractFactory("ZestyToken");
    zestyToken = await ZestyToken.deploy(signers[0].address);
    await zestyToken.deployed();

    const TokenVesting = await ethers.getContractFactory('TokenVesting');
    tokenVesting = await TokenVesting.deploy(signers[0].address, zestyToken.address);
    await tokenVesting.deployed();

    await zestyToken.approve(tokenVesting.address, 10000000);
  });

  it('It should show the right owner address', async function() {
    let data = await tokenVesting.owner();
    expect(data).to.equal(signers[0].address);
  });

  it('It should show the right token address', async function() {
    let data = await tokenVesting.getZestyTokenAddress();
    expect(data).to.equal(zestyToken.address);
  })

  it('It should allow for the creation of a vault only by the owner', async function() {
    await expect(tokenVesting.connect(signers[1]).newVault(
      signers[1].address,
      1000,
      1000,
      10
    )).to.be.reverted;

    await tokenVesting.newVault(
      signers[1].address,
      1000,
      1000,
      10
    );

    let data = await tokenVesting.getVault(signers[1].address);
    let timeNow = await time.latest();

    expect(data.startTime).to.equal(ethers.BigNumber.from(timeNow.toString()));
    expect(data.amount).to.equal(ethers.BigNumber.from(1000));
    expect(data.amountClaimed).to.equal(ethers.BigNumber.from(0));
    expect(data.vestingDuration).to.equal(ethers.BigNumber.from(1000));
    expect(data.vestingCliff).to.equal(ethers.BigNumber.from(10));

    let tokenAmount = await zestyToken.balanceOf(signers[0].address);
    expect(tokenAmount).to.equal(ethers.BigNumber.from("99999999999999999999999000"));
  });

  it('It should allow for the cancellation of a vault only by the owner', async function() {
    await tokenVesting.newVault(
      signers[1].address,
      1000,
      1000,
      10
    );

    await expect(tokenVesting.connect(signers[1]).cancelVault(signers[1].address)).to.be.reverted;

    await tokenVesting.cancelVault(signers[1].address);

    let data = await tokenVesting.getVault(signers[1].address);
    expect(data.startTime).to.equal(ethers.BigNumber.from(0));
    expect(data.amount).to.equal(ethers.BigNumber.from(0));
    expect(data.amountClaimed).to.equal(ethers.BigNumber.from(0));
    expect(data.vestingDuration).to.equal(ethers.BigNumber.from(0));
    expect(data.vestingCliff).to.equal(ethers.BigNumber.from(0));

    let tokenAmount = await zestyToken.balanceOf(signers[0].address);
    expect(tokenAmount).to.equal(ethers.BigNumber.from("100000000000000000000000000"));
  });

  it('It should not allow zero claims', async function() {
    await tokenVesting.newVault(
      signers[1].address,
      1000,
      1000,
      10
    );

    await expect(tokenVesting.connect(signers[1]).claimVault()).to.be.reverted;
  });

  it('It should allow for claims after cliff', async function() {
    await tokenVesting.newVault(
      signers[1].address,
      1000,
      1000,
      10
    );

    time.increase(5);

    await expect(tokenVesting.connect(signers[1]).claimVault()).to.be.reverted;

    time.increase(5);

    await tokenVesting.connect(signers[1]).claimVault();

    let tokenAmount = await zestyToken.balanceOf(signers[0].address);
    expect(tokenAmount).to.equal(ethers.BigNumber.from("99999999999999999999999000"));
    let tokenAmount2 = await zestyToken.balanceOf(signers[1].address);
    expect(tokenAmount2).to.equal(ethers.BigNumber.from("12"));

    await tokenVesting.connect(signers[1]).claimVault();

    data = await tokenVesting.getVault(signers[1].address);
    expect(data.amount).to.equal(ethers.BigNumber.from(1000));
    expect(data.amountClaimed).to.equal(ethers.BigNumber.from(13));
    expect(data.vestingDuration).to.equal(ethers.BigNumber.from(1000));
    expect(data.vestingCliff).to.equal(ethers.BigNumber.from(10));

    tokenAmount = await zestyToken.balanceOf(signers[0].address);
    expect(tokenAmount).to.equal(ethers.BigNumber.from("99999999999999999999999000"));
    tokenAmount2 = await zestyToken.balanceOf(signers[1].address);
    expect(tokenAmount2).to.equal(ethers.BigNumber.from("13"));

    time.increase(100);
    await tokenVesting.connect(signers[1]).claimVault();

    data = await tokenVesting.getVault(signers[1].address);
    expect(data.amount).to.equal(ethers.BigNumber.from(1000));
    expect(data.amountClaimed).to.equal(ethers.BigNumber.from(113));
    expect(data.vestingDuration).to.equal(ethers.BigNumber.from(1000));
    expect(data.vestingCliff).to.equal(ethers.BigNumber.from(10));

    tokenAmount = await zestyToken.balanceOf(signers[0].address);
    expect(tokenAmount).to.equal(ethers.BigNumber.from("99999999999999999999999000"));
    tokenAmount2 = await zestyToken.balanceOf(signers[1].address);
    expect(tokenAmount2).to.equal(ethers.BigNumber.from("113"));
  });

  it('It should give the right values after cancellation after cliff', async function() {
    await tokenVesting.newVault(
      signers[1].address,
      1000,
      1000,
      10
    );

    time.increase(10);

    await tokenVesting.cancelVault(signers[1].address);

    let data = await tokenVesting.getVault(signers[1].address);
    expect(data.amount).to.equal(ethers.BigNumber.from(0));
    expect(data.amountClaimed).to.equal(ethers.BigNumber.from(0));
    expect(data.vestingDuration).to.equal(ethers.BigNumber.from(0));
    expect(data.vestingCliff).to.equal(ethers.BigNumber.from(0));

    let tokenAmount = await zestyToken.balanceOf(signers[0].address);
    expect(tokenAmount).to.equal(ethers.BigNumber.from("99999999999999999999999990"));
    let tokenAmount2 = await zestyToken.balanceOf(signers[1].address);
    expect(tokenAmount2).to.equal(ethers.BigNumber.from("10"));

    await expect(tokenVesting.connect(signers[1]).claimVault()).to.be.reverted;
  });
 
  it('It should give out all vested tokens after vesting duration', async function() {
    await tokenVesting.newVault(
      signers[1].address,
      1000,
      1000,
      10
    );

    time.increase(1000);

    await tokenVesting.connect(signers[1]).claimVault();

    let data = await tokenVesting.getVault(signers[1].address);
    expect(data.amount).to.equal(ethers.BigNumber.from(1000));
    expect(data.amountClaimed).to.equal(ethers.BigNumber.from(1000));
    expect(data.vestingDuration).to.equal(ethers.BigNumber.from(1000));
    expect(data.vestingCliff).to.equal(ethers.BigNumber.from(10));

    let tokenAmount = await zestyToken.balanceOf(signers[0].address);
    expect(tokenAmount).to.equal(ethers.BigNumber.from("99999999999999999999999000"));
    let tokenAmount2 = await zestyToken.balanceOf(signers[1].address);
    expect(tokenAmount2).to.equal(ethers.BigNumber.from("1000"));

    await expect(tokenVesting.connect(signers[1]).claimVault()).to.be.reverted;

    time.increase(1000);
    await expect(tokenVesting.connect(signers[1]).claimVault()).to.be.reverted;
  });

});
