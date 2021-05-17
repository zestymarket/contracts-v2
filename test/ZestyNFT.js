const { expect } = require('chai');
const { intToBuffer } = require('ethjs-util');
const { ethers } = require('hardhat');

describe('ZestyNFT', function() {
  let zestyNFT;
  let signers;

  beforeEach(async () => {
    signers = await ethers.getSigners();

    const ZestyNFT = await ethers.getContractFactory('ZestyNFT');
    zestyNFT = await ZestyNFT.deploy(ethers.constants.AddressZero);
    await zestyNFT.deployed();
  });

  it('It should display name and symbol correctly', async function() {
    // Sanity check to see if everything is working properly
    expect(await zestyNFT.name()).to.equal('Zesty Market NFT');
    expect(await zestyNFT.symbol()).to.equal('ZESTYNFT');
  });
});