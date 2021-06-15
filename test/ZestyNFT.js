const { expect } = require('chai');
const { intToBuffer } = require('ethjs-util');
const { ethers } = require('hardhat');

describe('ZestyNFT', function() {
  let zestyNFT;
  let signers;

  beforeEach(async () => {
    signers = await ethers.getSigners();

    const ZestyNFT = await ethers.getContractFactory('ZestyNFT');
    zestyNFT = await ZestyNFT.deploy(signers[0].address, ethers.constants.AddressZero);
    await zestyNFT.deployed();
  });

  it('It should display name and symbol correctly', async function() {
    // Sanity check to see if everything is working properly
    expect(await zestyNFT.name()).to.equal('Zesty Market NFT');
    expect(await zestyNFT.symbol()).to.equal('ZESTYNFT');
  });

  it('It should show the zestyToken address as 0x0', async function() {
    expect(await zestyNFT.getZestyTokenAddress()).to.equal(ethers.constants.AddressZero);
  })

  it('It should allow people to mint tokens and get the right data and burn tokens', async function() {
    // Sanity check to see if everything is working properly
    await zestyNFT.mint('testURI');
    let data = await zestyNFT.getTokenData(0);
    expect(data.creator).to.equal(signers[0].address);
    expect(data.zestyTokenValue).to.equal(0);
    expect(data.uri).to.equal('testURI');

    await zestyNFT.burn(0);
  });

  it('It should only allow the creator to set URI when in possession of NFT', async function() {
    await zestyNFT.mint('testURI');
    let data = await zestyNFT.getTokenData(0);
    expect(data.creator).to.equal(signers[0].address);
    expect(data.zestyTokenValue).to.equal(0);
    expect(data.uri).to.equal('testURI');

    await zestyNFT.setTokenURI(0, 'testURI2');
    data = await zestyNFT.getTokenData(0);
    expect(data.creator).to.equal(signers[0].address);
    expect(data.zestyTokenValue).to.equal(0);
    expect(data.uri).to.equal('testURI2');

    await expect(zestyNFT.connect(signers[1]).setTokenURI('testURI2')).to.be.reverted;

    await zestyNFT.transferFrom(signers[0].address, signers[1].address, 0);
    expect(await zestyNFT.ownerOf(0)).to.equal(signers[1].address);
    await expect(zestyNFT.setTokenURI('testURI2')).to.be.reverted;
  });

  it('It should prevent people from locking tokens if token address is 0x0', async function() {
    // Sanity check to see if everything is working properly
    await zestyNFT.mint('testURI');
    await expect(zestyNFT.lockZestyToken(0, 1000)).to.be.reverted;
  });

  it('It should allow locking and retrieval of ZestyToken through burning', async function() {
    const ZestyToken = await ethers.getContractFactory('ZestyToken');
    zestyToken = await ZestyToken.deploy(signers[0].address);
    await zestyToken.deployed();

    await zestyNFT.setZestyTokenAddress(zestyToken.address);
    expect(await zestyNFT.getZestyTokenAddress()).to.equal(zestyToken.address);

    await zestyToken.approve(zestyNFT.address, 1000000000);

    let data = await zestyToken.balanceOf(signers[0].address);
    expect(data.toString()).to.equal("100000000000000000000000000");

    await zestyNFT.mint('testURI');
    zestyNFT.lockZestyToken(0, 1000);

    data = await zestyNFT.getTokenData(0);
    expect(data.creator).to.equal(signers[0].address);
    expect(data.zestyTokenValue).to.equal(1000);
    expect(data.uri).to.equal('testURI');
    expect(await zestyToken.balanceOf(zestyNFT.address)).to.equal(1000);

    zestyNFT.lockZestyToken(0, 1000);

    data = await zestyNFT.getTokenData(0);
    expect(data.creator).to.equal(signers[0].address);
    expect(data.zestyTokenValue).to.equal(2000);
    expect(data.uri).to.equal('testURI');
    expect(await zestyToken.balanceOf(zestyNFT.address)).to.equal(2000);

    await zestyNFT.burn(0);
    await expect(zestyNFT.getTokenData(0)).to.be.reverted;

    data = await zestyToken.balanceOf(signers[0].address);
    data = await zestyToken.balanceOf(zestyNFT.address);

    expect(await zestyToken.balanceOf(signers[0].address.toString())).to.equal("100000000000000000000000000");
    expect(await zestyToken.balanceOf(zestyNFT.address)).to.equal(0);

  });
});