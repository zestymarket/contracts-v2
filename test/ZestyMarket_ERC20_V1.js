const { expect } = require('chai');
const { ethers } = require('hardhat');
const { time } = require('@openzeppelin/test-helpers');

describe('ZestyMarket_ERC20_V1', function() {
  let signers;
  let zestyMarket;
  let timeNow;

  beforeEach(async () => {
    signers = await ethers.getSigners();
    timeNow = await time.latest();
    timeNow 
    timeNow = timeNow.toNumber();

    let ZestyToken = await ethers.getContractFactory('ZestyToken');
    zestyToken = await ZestyToken.deploy();
    await zestyToken.deployed();

    let ZestyNFT = await ethers.getContractFactory('ZestyNFT');
    zestyNFT = await ZestyNFT.deploy(zestyToken.address);

    let ZestyMarket = await ethers.getContractFactory('ZestyMarket_ERC20_V1');
    zestyMarket = await ZestyMarket.deploy(zestyToken.address, zestyNFT.address);
    await zestyMarket.deployed();

    await zestyNFT.deployed();
    await zestyNFT.mint('testUri');
    await zestyNFT.mint('testUri1');
    await zestyNFT.mint('testUri2');
    await zestyNFT.approve(zestyMarket.address, 0);
    await zestyToken.approve(zestyMarket.address, 100000000);
    await zestyToken.transfer(signers[1].address, 100000);
    await zestyToken.connect(signers[1]).approve(zestyMarket.address, 100000000);
    await zestyToken.transfer(signers[2].address, 100000);
    await zestyToken.connect(signers[2]).approve(zestyMarket.address, 100000000);
  });

  it('It should allow a buyer to create a campaign', async function() {
    await zestyMarket.buyerCampaignCreate('testUri');

    let data = await zestyMarket.getBuyerCampaign(1);
    expect(data.buyer).to.equal(signers[0].address);
    expect(data.uri).to.equal('testUri');
  });

  it('It should only allow a seller to deposit and withdraw an NFT', async function() {
    await zestyMarket.sellerNFTDeposit(0, 1);
    let data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(signers[0].address);
    expect(data.autoApprove).to.equal(1);
    expect(data.inProgressCount).to.equal(0);

    await expect(zestyMarket.connect(signers[1]).sellerNFTWithdraw(0)).to.be.reverted;

    await zestyMarket.sellerNFTWithdraw(0);
    data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(ethers.constants.AddressZero);
    expect(data.autoApprove).to.equal(0);
    expect(data.inProgressCount).to.equal(0);
  });

  it('It should prevent a seller from withdrawing an NFT once an auction takes place', async function() {
    await zestyMarket.sellerNFTDeposit(0, 1);
    let data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(signers[0].address);
    expect(data.autoApprove).to.equal(1);
    expect(data.inProgressCount).to.equal(0);

    await zestyMarket.sellerAuctionCreate(
      0,
      timeNow + 100,
      timeNow + 10000,
      timeNow + 101,
      timeNow + 10001,
      100
    );

    await expect(zestyMarket.sellerNFTWithdraw(0)).to.be.reverted;
  });

  it('It should allow a seller to withdraw an NFT once an auction is cancelled', async function() {
    await zestyMarket.sellerNFTDeposit(0, 1);
    let data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(signers[0].address);
    expect(data.autoApprove).to.equal(1);
    expect(data.inProgressCount).to.equal(0);

    await zestyMarket.sellerAuctionCreate(
      0,
      timeNow + 100,
      timeNow + 10000,
      timeNow + 101,
      timeNow + 10001,
      100
    );

    await expect(zestyMarket.sellerNFTWithdraw(0)).to.be.reverted;

    await expect(zestyMarket.sellerAuctionCancel(0)).to.be.reverted;
    await zestyMarket.sellerAuctionCancel(1);
    
    await zestyMarket.sellerNFTWithdraw(0);
    data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(ethers.constants.AddressZero);
    expect(data.autoApprove).to.equal(0);
    expect(data.inProgressCount).to.equal(0);
  });

  it('It should allow a seller to approve the ad if autoApprove is not enabled', async function() {

  });
});
