const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('StreamGame_ETH', function() {
  let streamGame;
  let signers;
  let provider;

  beforeEach(async () => {
    signers = await ethers.getSigners();
    provider = signers[0].provider;

    const StreamGame = await ethers.getContractFactory('StreamGame_ETH');
    streamGame = await StreamGame.deploy();
    await streamGame.deployed();
  });

  it('It should create a game, allow someone to donate, and allow creator to withdraw', async function() {
    // Start Game
    await streamGame.start();

    let data = await streamGame.getGameState(ethers.BigNumber.from(1));
    expect(data.creator).to.equal(signers[0].address);
    expect(data.currentDonor).to.equal(ethers.constants.AddressZero);
    expect(data.totalDonations).to.equal(ethers.constants.Zero);
    expect(data.currentMessage).to.equal('');

    // Donate
    await streamGame.connect(signers[1]).donate(1, 'test', {value: 1000});
    let data1 = await streamGame.getGameState(ethers.BigNumber.from(1));
    expect(data1.creator).to.equal(signers[0].address);
    expect(data1.currentDonor).to.equal(signers[1].address);
    expect(data1.totalDonations).to.equal(ethers.BigNumber.from(1000));
    expect(data1.currentMessage).to.equal('test');
    
    await streamGame.connect(signers[2]).donate(1, 'test2', {value: 2000});
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

    let balance = await provider.getBalance(signers[0].address);
    expect(balance).to.equal(ethers.BigNumber.from("9999992388656000003000"));
  });

  it('It should prevent donation to a non-existent game', async function() {
    // Donate
    await expect(streamGame.connect(signers[1]).donate(1, 'test', {value: 1000})).to.be.reverted;
  });

  it('It should prevent withdrawal from a non-existent game', async function() {
    await expect(streamGame.connect(signers[1]).withdraw(1)).to.be.reverted;
  })
});
