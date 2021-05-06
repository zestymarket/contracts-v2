const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('StreamGame', function() {
  let zestyToken;
  let streamGame;
  let signers;

  beforeEach(async () => {
    signers = await ethers.getSigners();

    const ZestyToken = await ethers.getContractFactory('ZestyToken');
    zestyToken = await ZestyToken.deploy();
    await zestyToken.deployed();
    

    const StreamGame = await ethers.getContractFactory('StreamGame');
    streamGame = await StreamGame.deploy(zestyToken.address);
    await streamGame.deployed();

    await zestyToken.approve(streamGame.address, 100000000);
    await zestyToken.transfer(signers[1].address, 100000);
    await zestyToken.connect(signers[1]).approve(streamGame.address, 100000000);
    await zestyToken.transfer(signers[2].address, 100000);
    await zestyToken.connect(signers[2]).approve(streamGame.address, 100000000);
  });

  it('It should have the right usdc address', async function() {
    let data = await streamGame.getUsdcAddress()
    expect(data).to.equal(zestyToken.address);
  })

  it('It should create a game, allow someone to donate, and allow creator to withdraw', async function() {
    // Start Game
    await streamGame.start();

    let data = await streamGame.getGameState(ethers.BigNumber.from(1));
    expect(data.creator).to.equal(signers[0].address);
    expect(data.currentDonor).to.equal(ethers.constants.AddressZero);
    expect(data.totalDonations).to.equal(ethers.constants.Zero);
    expect(data.currentMessage).to.equal('');

    // Donate
    await streamGame.connect(signers[1]).donate(1, 1000, 'test');
    let data1 = await streamGame.getGameState(ethers.BigNumber.from(1));
    expect(data1.creator).to.equal(signers[0].address);
    expect(data1.currentDonor).to.equal(signers[1].address);
    expect(data1.totalDonations).to.equal(ethers.BigNumber.from(1000));
    expect(data1.currentMessage).to.equal('test');
    
    await streamGame.connect(signers[2]).donate(1, 2000, 'test2');
    let data2 = await streamGame.getGameState(ethers.BigNumber.from(1));
    expect(data2.creator).to.equal(signers[0].address);
    expect(data2.currentDonor).to.equal(signers[2].address);
    expect(data2.totalDonations).to.equal(ethers.BigNumber.from(3000));
    expect(data2.currentMessage).to.equal('test2');

    // Withdraw
    await streamGame.connect(signers[3]).withdraw(ethers.BigNumber.from(1));
    let data3 = await streamGame.getGameState(ethers.BigNumber.from(1));
    expect(data3.creator).to.equal(signers[0].address);
    expect(data3.currentDonor).to.equal(signers[2].address);
    expect(data3.totalDonations).to.equal(ethers.BigNumber.from(0));
    expect(data3.currentMessage).to.equal('test2');

    let data4 = await zestyToken.balanceOf(signers[0].address);
    expect(data4).to.equal(ethers.BigNumber.from("99999999999999999999803000")); // total - 200000 + 3000
  });

  it('It should prevent donation to a non-existent game', async function() {
    // Donate
    await expect(streamGame.connect(signers[1]).donate(1, 1000, 'test')).to.be.reverted;
  });

  it('It should prevent withdrawal from a non-existent game', async function() {
    await expect(streamGame.connect(signers[1]).withdraw(1)).to.be.reverted;
  })
});
