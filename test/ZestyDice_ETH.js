const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('ZestyDice_ETH', function() {
  let streamGame;
  let signers;
  let provider;

  beforeEach(async () => {
    signers = await ethers.getSigners();
    provider = signers[0].provider;

    const ZestyDice = await ethers.getContractFactory('ZestyDice_ETH');
    zestyDice = await ZestyDice.deploy();
    await zestyDice.deployed();
  });

  it('It should create a game, allow someone to donate, and allow creator to withdraw', async function() {
    let oldbalance = await provider.getBalance(signers[0].address);

    // Start Game
    await zestyDice.start();

    let data = await zestyDice.getGameState(ethers.BigNumber.from(1));
    expect(data.creator).to.equal(signers[0].address);
    expect(data.currentDonor).to.equal(ethers.constants.AddressZero);
    expect(data.totalDonations).to.equal(ethers.constants.Zero);
    expect(data.currentMessage).to.equal('');
    expect(data.currentDiceRoll).to.equal(0);

    // Donate
    await zestyDice.connect(signers[1]).donate(1, 'test', {value: 1000});
    let data1 = await zestyDice.getGameState(ethers.BigNumber.from(1));
    expect(data1.creator).to.equal(signers[0].address);
    expect(data1.currentDonor).to.equal(signers[1].address);
    expect(data1.totalDonations).to.equal(ethers.BigNumber.from(1000));
    expect(data1.currentMessage).to.equal('test');
    
    await zestyDice.connect(signers[2]).donate(1, 'test2', {value: 2000});
    let data2 = await zestyDice.getGameState(ethers.BigNumber.from(1));
    expect(data2.creator).to.equal(signers[0].address);
    expect(data2.currentDonor).to.equal(signers[2].address);
    expect(data2.totalDonations).to.equal(ethers.BigNumber.from(3000));
    expect(data2.currentMessage).to.equal('test2');
    let currentDiceRoll = data2.currentDiceRoll;

    // Withdraw
    await zestyDice.connect(signers[3]).withdraw(ethers.BigNumber.from(1));
    let data3 = await zestyDice.getGameState(ethers.BigNumber.from(1));
    expect(data3.creator).to.equal(signers[0].address);
    expect(data3.currentDonor).to.equal(signers[2].address);
    expect(data3.totalDonations).to.equal(ethers.BigNumber.from(0));
    expect(data3.currentMessage).to.equal('test2');
    expect(data3.currentDiceRoll).to.equal(currentDiceRoll);

    let balance = await provider.getBalance(signers[0].address);
    expect(balance.mod(10000)).to.equal(oldbalance.add(ethers.BigNumber.from(3000)).mod(10000));
  });

  it('It should prevent donation to a non-existent game', async function() {
    // Donate
    await expect(zestyDice.connect(signers[1]).donate(1, 'test', {value: 1000})).to.be.reverted;
  });

  it('It should prevent withdrawal from a non-existent game', async function() {
    await expect(zestyDice.connect(signers[1]).withdraw(1)).to.be.reverted;
  })
});
