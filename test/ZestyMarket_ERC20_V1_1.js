const { expect } = require('chai');
const { ethers } = require('hardhat');
const { time } = require('@openzeppelin/test-helpers');

describe('ZestyMarket_ERC20_V1_1', function() {
  let signers;
  let zestyMarket;
  let timeNow;

  beforeEach(async () => {
    signers = await ethers.getSigners();
    timeNow = await time.latest();
    timeNow = timeNow.toNumber();

    let ZestyToken = await ethers.getContractFactory('ZestyToken');
    zestyToken = await ZestyToken.deploy(signers[0].address);
    await zestyToken.deployed();

    let ZestyNFT = await ethers.getContractFactory('ZestyNFT');
    zestyNFT = await ZestyNFT.deploy(signers[0].address, zestyToken.address);

    let ZestyMarket = await ethers.getContractFactory('ZestyMarket_ERC20_V1_1');
    zestyMarket = await ZestyMarket.deploy(zestyToken.address, zestyNFT.address, signers[0].address);
    await zestyMarket.deployed();

    await zestyNFT.deployed();
    await zestyNFT.mint('testUri');
    await zestyNFT.mint('testUri1');
    await zestyNFT.connect(signers[3]).mint('testUri2');
    await zestyNFT.approve(zestyMarket.address, 0);
    await zestyNFT.approve(zestyMarket.address, 1);
    await zestyNFT.connect(signers[3]).approve(zestyMarket.address, 2);
    await zestyToken.approve(zestyMarket.address, 100000000);
    await zestyToken.transfer(signers[1].address, 100000);
    await zestyToken.connect(signers[1]).approve(zestyMarket.address, 100000000);
    await zestyToken.transfer(signers[2].address, 100000);
    await zestyToken.connect(signers[2]).approve(zestyMarket.address, 100000000);
    await zestyToken.transfer(signers[3].address, 100000);
    await zestyToken.connect(signers[3]).approve(zestyMarket.address, 100000000);
  });

  it('It should allow a buyer to create a campaign', async function() {
    await zestyMarket.buyerCampaignCreate('testUri');

    let data = await zestyMarket.getBuyerCampaign(1);
    expect(data.buyer).to.equal(signers[0].address);
    expect(data.uri).to.equal('testUri');
  });

  it('It should only allow a seller to deposit and withdraw an NFT', async function() {
    await expect(zestyMarket.sellerNFTWithdraw(0)).to.be.reverted;
    await zestyMarket.sellerNFTDeposit(0, 1);
    let data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(signers[0].address);
    expect(data.autoApprove).to.equal(1);
    expect(data.inProgressCount).to.equal(0);

    // cannot double deposit
    await expect(zestyMarket.sellerNFTDeposit(0, 1)).to.be.reverted;

    await expect(zestyMarket.connect(signers[1]).sellerNFTWithdraw(0)).to.be.reverted;

    await zestyMarket.sellerNFTWithdraw(0);
    data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(ethers.constants.AddressZero);
    expect(data.autoApprove).to.equal(0);
    expect(data.inProgressCount).to.equal(0);
  });

  it('[batched] It should allow a buyer to cancel a bid if the seller has not approved', async function() {
    // create campaignj
    await zestyMarket.connect(signers[1]).buyerCampaignCreate('testUri');

    // Deposit NFT
    await zestyMarket.sellerNFTDeposit(0, 1);

    await zestyMarket.sellerAuctionCreateBatch(
      0,
      [timeNow + 100, timeNow + 100, timeNow + 100],
      [timeNow + 10000, timeNow + 10000, timeNow + 10000],
      [timeNow + 101, timeNow + 101, timeNow + 101],
      [timeNow + 10001, timeNow + 10001, timeNow + 10001],
      [100, 100, 100]
    );

    await time.increase(200);

    await zestyMarket.connect(signers[1]).sellerAuctionBidBatch([1, 2, 3], 1);

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(signers[0].address);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(timeNow + 100);
      expect(data.auctionTimeEnd).to.equal(timeNow + 10000);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.priceStart).to.equal(100);
      expect(data.pricePending).to.equal(98);
      expect(data.priceEnd).to.equal(0);
      expect(data.buyerCampaign).to.equal(1);
      expect(data.buyerCampaignApproved).to.equal(1);
    }

    await zestyMarket.connect(signers[1]).sellerAuctionBidCancelBatch([1,2,3]);

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(signers[0].address);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(timeNow + 100);
      expect(data.auctionTimeEnd).to.equal(timeNow + 10000);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.priceStart).to.equal(100);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(0);
      expect(data.buyerCampaign).to.equal(0);
      expect(data.buyerCampaignApproved).to.equal(1);
    }
    // seller cannot withdraw token as auction is still in progress
    await expect(zestyMarket.sellerNFTWithdraw(0)).to.be.reverted;

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(100000);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(0);
  });  

  it('[batched] It should allow a seller to reject the ad if autoApprove is disabled', async function() {
    // create campaign
    await zestyMarket.connect(signers[1]).buyerCampaignCreate('testUri');

    // Deposit NFT
    await zestyMarket.sellerNFTDeposit(0, 1);

    let atsList = [timeNow + 100, timeNow + 100, timeNow + 100];
    let ateList = [timeNow + 10000, timeNow + 10000, timeNow + 10000];
    let ctsList = [timeNow + 101, timeNow + 101, timeNow + 101];
    let cteList = [timeNow + 10001, timeNow + 10001, timeNow + 10001];
    let priceList = [100, 100, 100];

    await zestyMarket.sellerAuctionCreateBatch(
      0,
      atsList,
      ateList,
      ctsList,
      cteList,
      priceList
    );

    await expect(zestyMarket.connect(signers[1]).sellerAuctionBidBatch([1,2,3], 1)).to.be.reverted;

    await time.increase(200);

    await zestyMarket.connect(signers[1]).sellerAuctionBidBatch([1,2,3], 1);

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(signers[0].address);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(timeNow + 100);
      expect(data.auctionTimeEnd).to.equal(timeNow + 10000);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.priceStart).to.equal(100);
      expect(data.pricePending).to.equal(98);
      expect(data.priceEnd).to.equal(0);
      expect(data.buyerCampaign).to.equal(1);
      expect(data.buyerCampaignApproved).to.equal(1);
    }

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(99706);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(294);

    // seller cannot withdraw token after bidding happened
    await expect(zestyMarket.sellerNFTWithdraw(0)).to.be.reverted;

    // seller cannot cancel once there's a bid
    await expect(zestyMarket.sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    await zestyMarket.sellerAuctionRejectBatch([1,2,3]);

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(signers[0].address);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(timeNow + 100);
      expect(data.auctionTimeEnd).to.equal(timeNow + 10000);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.priceStart).to.equal(100);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(0);
      expect(data.buyerCampaign).to.equal(0);
      expect(data.buyerCampaignApproved).to.equal(1);
    }

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(100000);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(0);

    // allow cancellation and withdrawal of NFT once rejection occured
    await zestyMarket.sellerAuctionCancelBatch([1,2,3]);
    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(ethers.constants.AddressZero);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(0);
      expect(data.auctionTimeEnd).to.equal(0);
      expect(data.contractTimeStart).to.equal(0);
      expect(data.contractTimeEnd).to.equal(0);
      expect(data.priceStart).to.equal(0);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(0);
      expect(data.buyerCampaign).to.equal(0);
      expect(data.buyerCampaignApproved).to.equal(0);
    }

    await expect(zestyMarket.sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    await zestyMarket.sellerNFTWithdraw(0);
    data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(ethers.constants.AddressZero);
    expect(data.autoApprove).to.equal(0);
    expect(data.inProgressCount).to.equal(0);

    expect(await zestyNFT.ownerOf(0)).to.equal(signers[0].address);
  });

  it('[batched] It should allow a seller to approve the ad if autoApprove is disabled and withdraw when complete', async function() {
    // create campaignj
    await zestyMarket.connect(signers[1]).buyerCampaignCreate('testUri');

    // Deposit NFT
    await zestyMarket.sellerNFTDeposit(0, 1);

    let atsList = [timeNow + 100, timeNow + 100, timeNow + 100];
    let ateList = [timeNow + 10000, timeNow + 10000, timeNow + 10000];
    let ctsList = [timeNow + 101, timeNow + 101, timeNow + 101];
    let cteList = [timeNow + 10001, timeNow + 10001, timeNow + 10001];
    let priceList = [100, 100, 100];

    await zestyMarket.sellerAuctionCreateBatch(
      0,
      atsList,
      ateList,
      ctsList,
      cteList,
      priceList
    );

    await time.increase(200);

    await zestyMarket.connect(signers[1]).sellerAuctionBidBatch([1,2,3], 1)

    // seller cannot withdraw token after bidding happened
    await expect(zestyMarket.sellerNFTWithdraw(0)).to.be.reverted;

    // seller cannot cancel once there's a bid
    await expect(zestyMarket.sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    await zestyMarket.sellerAuctionApproveBatch([1,2,3]);
    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(1);
      expect(data.seller).to.equal(signers[0].address);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(timeNow + 100);
      expect(data.auctionTimeEnd).to.equal(timeNow + 10000);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.priceStart).to.equal(100);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(98);
      expect(data.buyerCampaign).to.equal(1);
      expect(data.buyerCampaignApproved).to.equal(2);
    }

    // seller cannot withdraw token after bidding happened
    await expect(zestyMarket.sellerNFTWithdraw(0)).to.be.reverted;

    // seller cannot cancel after approval
    await expect(zestyMarket.sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    // seller cannot withdraw immediately after approval
    await expect(zestyMarket.contractWithdrawBatch([1,2,3])).to.be.reverted;

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(99706);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(294);

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getContract(i);
      expect(data.sellerAuctionId).to.equal(i);
      expect(data.buyerCampaignId).to.equal(1);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.contractValue).to.equal(98);
      expect(data.withdrawn).to.equal(1);
    }
    
    time.increase(10050);

    await zestyMarket.contractWithdrawBatch([1,2,3]);
    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getContract(i);
      expect(data.sellerAuctionId).to.equal(i);
      expect(data.buyerCampaignId).to.equal(1);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.contractValue).to.equal(98);
      expect(data.withdrawn).to.equal(2);
    }

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(99706);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(0);

    data = await zestyToken.balanceOf(signers[0].address);
    expect(data).to.equal(ethers.BigNumber.from('99999999999999999999700294'));

    // cannot double withdraw
    await expect(zestyMarket.contractWithdrawBatch([1,2,3])).to.be.reverted;

    // allow withdrawal of NFT once process is complete
    await expect(zestyMarket.sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    await zestyMarket.sellerNFTWithdraw(0);
    data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(ethers.constants.AddressZero);
    expect(data.autoApprove).to.equal(0);
    expect(data.inProgressCount).to.equal(0);
  });

  it('[batched] It should not allow a seller to cancel the ad if autoApprove is enabled. Allow withdraw when complete', async function() {
    // create campaignj
    await zestyMarket.connect(signers[1]).buyerCampaignCreate('testUri');

    // Deposit NFT
    await zestyMarket.sellerNFTDeposit(0, 2);

    let atsList = [timeNow + 100, timeNow + 100, timeNow + 100];
    let ateList = [timeNow + 10000, timeNow + 10000, timeNow + 10000];
    let ctsList = [timeNow + 101, timeNow + 101, timeNow + 101];
    let cteList = [timeNow + 10001, timeNow + 10001, timeNow + 10001];
    let priceList = [100, 100, 100];

    await zestyMarket.sellerAuctionCreateBatch(
      0,
      atsList,
      ateList,
      ctsList,
      cteList,
      priceList
    );

    await time.increase(200);

    await zestyMarket.connect(signers[1]).sellerAuctionBidBatch([1,2,3], 1)

    // seller cannot withdraw token after bidding happened
    await expect(zestyMarket.sellerNFTWithdraw(0)).to.be.reverted;

    // seller cannot cancel once there's a bid
    await expect(zestyMarket.sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    // seller does not need to approve
    await expect(zestyMarket.sellerAuctionApproveBatch([1,2,3])).to.be.reverted;
    // seller cannot reject
    await expect(zestyMarket.sellerAuctionRejectBatch([1,2,3])).to.be.reverted;

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(signers[0].address);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(timeNow + 100);
      expect(data.auctionTimeEnd).to.equal(timeNow + 10000);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.priceStart).to.equal(100);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(98);
      expect(data.buyerCampaign).to.equal(1);
      expect(data.buyerCampaignApproved).to.equal(2);
    }

    // seller cannot withdraw token after bidding happened
    await expect(zestyMarket.sellerNFTWithdraw(0)).to.be.reverted;

    // seller cannot cancel after approval
    await expect(zestyMarket.sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    // seller cannot withdraw immediately after approval
    await expect(zestyMarket.contractWithdrawBatch([1,2,3])).to.be.reverted;

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(99706);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(294);

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getContract(i);
      expect(data.sellerAuctionId).to.equal(i);
      expect(data.buyerCampaignId).to.equal(1);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.contractValue).to.equal(98);
      expect(data.withdrawn).to.equal(1);
    }
    
    time.increase(10050);

    await zestyMarket.contractWithdrawBatch([1,2,3]);

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getContract(1);
      expect(data.sellerAuctionId).to.equal(1);
      expect(data.buyerCampaignId).to.equal(1);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.contractValue).to.equal(98);
      expect(data.withdrawn).to.equal(2);
    }

    // cannot double withdraw
    await expect(zestyMarket.contractWithdrawBatch([1,2,3])).to.be.reverted;

    // allow withdrawal of NFT once process is complete
    await expect(zestyMarket.sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    data = await zestyToken.balanceOf(signers[0].address);
    await expect(data.toString()).to.equal("99999999999999999999700294");

    await zestyMarket.sellerNFTWithdraw(0);
    data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(ethers.constants.AddressZero);
    expect(data.autoApprove).to.equal(0);
    expect(data.inProgressCount).to.equal(0);
  });

  it("[batched] It should not allow a user to cancel auction, approve auction, reject auction, without creating an auction", async function() { 
    await expect(zestyMarket.sellerAuctionCancelBatch([1,2,3])).to.be.reverted;
    await expect(zestyMarket.sellerAuctionRejectBatch([1,2,3])).to.be.reverted;
    await expect(zestyMarket.sellerAuctionApproveBatch([1,2,3])).to.be.reverted;
    await expect(zestyMarket.contractWithdrawBatch([1,2,3])).to.be.reverted;
  });

  it('[batched] It should allow an operator to reject the ad if autoApprove is disabled', async function() {
    // create campaign
    await zestyMarket.connect(signers[1]).buyerCampaignCreate('testUri');

    // Deposit NFT
    await zestyMarket.sellerNFTDeposit(0, 1);

    let atsList = [timeNow + 100, timeNow + 100, timeNow + 100];
    let ateList = [timeNow + 10000, timeNow + 10000, timeNow + 10000];
    let ctsList = [timeNow + 101, timeNow + 101, timeNow + 101];
    let cteList = [timeNow + 10001, timeNow + 10001, timeNow + 10001];
    let priceList = [100, 100, 100];

    await expect(zestyMarket.connect(signers[2]).sellerAuctionCreateBatch(
      0,
      atsList,
      ateList,
      ctsList,
      cteList,
      priceList
    )).to.be.reverted;

    await zestyMarket.authorizeOperator(signers[2].address);

    await zestyMarket.connect(signers[2]).sellerAuctionCreateBatch(
      0,
      atsList,
      ateList,
      ctsList,
      cteList,
      priceList
    );

    await time.increase(200);

    await expect(zestyMarket.connect(signers[2]).sellerAuctionBidBatch([1,2,3], 1)).to.be.reverted;

    await zestyMarket.connect(signers[1]).authorizeOperator(signers[2].address);

    await zestyMarket.connect(signers[2]).sellerAuctionBidBatch([1,2,3], 1);

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(signers[0].address);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(timeNow + 100);
      expect(data.auctionTimeEnd).to.equal(timeNow + 10000);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.priceStart).to.equal(100);
      expect(data.pricePending).to.equal(98);
      expect(data.priceEnd).to.equal(0);
      expect(data.buyerCampaign).to.equal(1);
      expect(data.buyerCampaignApproved).to.equal(1);
    }

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(99706);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(294);

    // seller cannot withdraw token after bidding happened
    await expect(zestyMarket.connect(signers[2]).sellerNFTWithdraw(0)).to.be.reverted;

    // seller cannot cancel once there's a bid
    await expect(zestyMarket.connect(signers[2]).sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    await zestyMarket.connect(signers[2]).sellerAuctionRejectBatch([1,2,3]);

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(signers[0].address);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(timeNow + 100);
      expect(data.auctionTimeEnd).to.equal(timeNow + 10000);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.priceStart).to.equal(100);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(0);
      expect(data.buyerCampaign).to.equal(0);
      expect(data.buyerCampaignApproved).to.equal(1);
    }

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(100000);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(0);

    data = await zestyToken.balanceOf(signers[0].address);
    expect(data.toString()).to.equal("99999999999999999999700000");

    // allow cancellation and withdrawal of NFT once rejection occured
    await zestyMarket.connect(signers[2]).sellerAuctionCancelBatch([1,2,3]);
    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(ethers.constants.AddressZero);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(0);
      expect(data.auctionTimeEnd).to.equal(0);
      expect(data.contractTimeStart).to.equal(0);
      expect(data.contractTimeEnd).to.equal(0);
      expect(data.priceStart).to.equal(0);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(0);
      expect(data.buyerCampaign).to.equal(0);
      expect(data.buyerCampaignApproved).to.equal(0);
    }

    await expect(zestyMarket.sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    await zestyMarket.sellerNFTWithdraw(0);
    data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(ethers.constants.AddressZero);
    expect(data.autoApprove).to.equal(0);
    expect(data.inProgressCount).to.equal(0);
  });

  it('[batched] It should allow a seller to approve the ad if autoApprove is disabled and withdraw when complete', async function() {
    // create campaignj
    await zestyMarket.connect(signers[1]).buyerCampaignCreate('testUri');

    // Deposit NFT
    await zestyMarket.sellerNFTDeposit(0, 1);

    await zestyMarket.authorizeOperator(signers[2].address);
    await zestyMarket.connect(signers[1]).authorizeOperator(signers[2].address);

    let atsList = [timeNow + 100, timeNow + 100, timeNow + 100];
    let ateList = [timeNow + 10000, timeNow + 10000, timeNow + 10000];
    let ctsList = [timeNow + 101, timeNow + 101, timeNow + 101];
    let cteList = [timeNow + 10001, timeNow + 10001, timeNow + 10001];
    let priceList = [100, 100, 100];

    await zestyMarket.sellerAuctionCreateBatch(
      0,
      atsList,
      ateList,
      ctsList,
      cteList,
      priceList
    );

    await time.increase(200);

    await zestyMarket.connect(signers[2]).sellerAuctionBidBatch([1,2,3], 1)

    // seller cannot withdraw token after bidding happened
    await expect(zestyMarket.connect(signers[2]).sellerNFTWithdraw(0)).to.be.reverted;

    // seller cannot cancel once there's a bid
    await expect(zestyMarket.connect(signers[2]).sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    await zestyMarket.connect(signers[2]).sellerAuctionApproveBatch([1,2,3]);
    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(1);
      expect(data.seller).to.equal(signers[0].address);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(timeNow + 100);
      expect(data.auctionTimeEnd).to.equal(timeNow + 10000);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.priceStart).to.equal(100);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(98);
      expect(data.buyerCampaign).to.equal(1);
      expect(data.buyerCampaignApproved).to.equal(2);
    }

    // seller cannot withdraw token after bidding happened
    await expect(zestyMarket.sellerNFTWithdraw(0)).to.be.reverted;

    // seller cannot cancel after approval
    await expect(zestyMarket.connect(signers[2]).sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    // seller cannot withdraw immediately after approval
    await expect(zestyMarket.connect(signers[2]).contractWithdrawBatch([1,2,3])).to.be.reverted;

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(99706);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(294);

    data = await zestyToken.balanceOf(signers[0].address);
    expect(data.toString()).to.equal("99999999999999999999700000");

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getContract(i);
      expect(data.sellerAuctionId).to.equal(i);
      expect(data.buyerCampaignId).to.equal(1);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.contractValue).to.equal(98);
      expect(data.withdrawn).to.equal(1);
    }
    
    time.increase(10050);

    await zestyMarket.connect(signers[2]).contractWithdrawBatch([1,2,3]);
    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getContract(i);
      expect(data.sellerAuctionId).to.equal(i);
      expect(data.buyerCampaignId).to.equal(1);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.contractValue).to.equal(98);
      expect(data.withdrawn).to.equal(2);
    }

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(99706);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(0);

    data = await zestyToken.balanceOf(signers[0].address);
    expect(data).to.equal(ethers.BigNumber.from('99999999999999999999700294'));

    // cannot double withdraw
    await expect(zestyMarket.connect(signers[2]).contractWithdrawBatch([1,2,3])).to.be.reverted;

    // allow withdrawal of NFT once process is complete
    await expect(zestyMarket.connect(signers[2]).sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    await expect(zestyMarket.connect(signers[2]).sellerNFTWithdraw(0)).to.be.reverted;

    await zestyMarket.sellerNFTWithdraw(0);
    data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(ethers.constants.AddressZero);
    expect(data.autoApprove).to.equal(0);
    expect(data.inProgressCount).to.equal(0);
  });

  it('[batched] It should not allow a seller to cancel the ad if autoApprove is enabled. Allow withdraw when complete', async function() {
    // create campaignj
    await zestyMarket.connect(signers[1]).buyerCampaignCreate('testUri');

    // Deposit NFT
    await zestyMarket.sellerNFTDeposit(0, 2);

    await zestyMarket.authorizeOperator(signers[2].address);
    await zestyMarket.connect(signers[1]).authorizeOperator(signers[2].address);

    let atsList = [timeNow + 100, timeNow + 100, timeNow + 100];
    let ateList = [timeNow + 10000, timeNow + 10000, timeNow + 10000];
    let ctsList = [timeNow + 101, timeNow + 101, timeNow + 101];
    let cteList = [timeNow + 10001, timeNow + 10001, timeNow + 10001];
    let priceList = [100, 100, 100];

    await zestyMarket.sellerAuctionCreateBatch(
      0,
      atsList,
      ateList,
      ctsList,
      cteList,
      priceList
    );

    await time.increase(200);

    await zestyMarket.connect(signers[2]).sellerAuctionBidBatch([1,2,3], 1)

    // seller cannot withdraw token after bidding happened
    await expect(zestyMarket.sellerNFTWithdraw(0)).to.be.reverted;

    // seller cannot cancel once there's a bid
    await expect(zestyMarket.connect(signers[2]).sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    // seller does not need to approve
    await expect(zestyMarket.connect(signers[2]).sellerAuctionApproveBatch([1,2,3])).to.be.reverted;
    // seller cannot reject
    await expect(zestyMarket.connect(signers[2]).sellerAuctionRejectBatch([1,2,3])).to.be.reverted;

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(signers[0].address);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(timeNow + 100);
      expect(data.auctionTimeEnd).to.equal(timeNow + 10000);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.priceStart).to.equal(100);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(98);
      expect(data.buyerCampaign).to.equal(1);
      expect(data.buyerCampaignApproved).to.equal(2);
    }

    // seller cannot withdraw token after bidding happened
    await expect(zestyMarket.connect(signers[2]).sellerNFTWithdraw(0)).to.be.reverted;

    // seller cannot cancel after approval
    await expect(zestyMarket.connect(signers[2]).sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    // seller cannot withdraw immediately after approval
    await expect(zestyMarket.connect(signers[2]).contractWithdrawBatch([1,2,3])).to.be.reverted;

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(99706);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(294);

    data = await zestyToken.balanceOf(signers[0].address);
    expect(data.toString()).to.equal("99999999999999999999700000");

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getContract(i);
      expect(data.sellerAuctionId).to.equal(i);
      expect(data.buyerCampaignId).to.equal(1);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.contractValue).to.equal(98);
      expect(data.withdrawn).to.equal(1);
    }
    
    time.increase(10050);

    await zestyMarket.connect(signers[2]).contractWithdrawBatch([1,2,3]);

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getContract(1);
      expect(data.sellerAuctionId).to.equal(1);
      expect(data.buyerCampaignId).to.equal(1);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.contractValue).to.equal(98);
      expect(data.withdrawn).to.equal(2);
    }

    // cannot double withdraw
    await expect(zestyMarket.connect(signers[2]).contractWithdrawBatch([1,2,3])).to.be.reverted;

    // allow withdrawal of NFT once process is complete
    await expect(zestyMarket.connect(signers[2]).sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    await zestyMarket.sellerNFTWithdraw(0);
    data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(ethers.constants.AddressZero);
    expect(data.autoApprove).to.equal(0);
    expect(data.inProgressCount).to.equal(0);
  });

  it('[batched] It should not allow a buyer to bid on the ad when banned.', async function() {
    // create campaignj
    await zestyMarket.connect(signers[1]).buyerCampaignCreate('testUri');

    // Deposit NFT
    await zestyMarket.sellerNFTDeposit(0, 2);

    await zestyMarket.authorizeOperator(signers[2].address);
    await zestyMarket.connect(signers[1]).authorizeOperator(signers[2].address);

    let atsList = [timeNow + 100, timeNow + 100, timeNow + 100];
    let ateList = [timeNow + 10000, timeNow + 10000, timeNow + 10000];
    let ctsList = [timeNow + 101, timeNow + 101, timeNow + 101];
    let cteList = [timeNow + 10001, timeNow + 10001, timeNow + 10001];
    let priceList = [100, 100, 100];

    await zestyMarket.sellerAuctionCreateBatch(
      0,
      atsList,
      ateList,
      ctsList,
      cteList,
      priceList
    );

    await zestyMarket.sellerBan(signers[1].address);

    await time.increase(200);

    await expect(zestyMarket.connect(signers[1]).sellerAuctionBidBatch([1,2,3], 1)).to.be.reverted;
    await expect(zestyMarket.connect(signers[2]).sellerAuctionBidBatch([1,2,3], 1)).to.be.reverted;

    await zestyMarket.sellerUnban(signers[1].address);


    await zestyMarket.connect(signers[2]).sellerAuctionBidBatch([1,2,3], 1);

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(signers[0].address);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(timeNow + 100);
      expect(data.auctionTimeEnd).to.equal(timeNow + 10000);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.priceStart).to.equal(100);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(98);
      expect(data.buyerCampaign).to.equal(1);
      expect(data.buyerCampaignApproved).to.equal(2);
    }

    // seller cannot withdraw token after bidding happened
    await expect(zestyMarket.sellerNFTWithdraw(0)).to.be.reverted;
  });

  it('[batched] It should allow a seller to cancel an auction after creating the auction', async function() {
    // Deposit NFT
    await zestyMarket.sellerNFTDeposit(0, 1);
    
    let atsList = [timeNow + 100, timeNow + 100, timeNow + 100];
    let ateList = [timeNow + 10000, timeNow + 10000, timeNow + 10000];
    let ctsList = [timeNow + 101, timeNow + 101, timeNow + 101];
    let cteList = [timeNow + 10001, timeNow + 10001, timeNow + 10001];
    let priceList = [100, 100, 100];

    await zestyMarket.sellerAuctionCreateBatch(
      0,
      atsList,
      ateList,
      ctsList,
      cteList,
      priceList
    );

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(signers[0].address);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(timeNow + 100);
      expect(data.auctionTimeEnd).to.equal(timeNow + 10000);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.priceStart).to.equal(100);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(0);
      expect(data.buyerCampaign).to.equal(0);
      expect(data.buyerCampaignApproved).to.equal(1);
    }

    data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(signers[0].address);
    expect(data.autoApprove).to.equal(1);
    expect(data.inProgressCount).to.equal(3);

    await time.increase(200);

    await zestyMarket.sellerAuctionCancelBatch([1,2,3]);

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(ethers.constants.AddressZero);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(0);
      expect(data.auctionTimeEnd).to.equal(0);
      expect(data.contractTimeStart).to.equal(0);
      expect(data.contractTimeEnd).to.equal(0);
      expect(data.priceStart).to.equal(0);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(0);
      expect(data.buyerCampaign).to.equal(0);
      expect(data.buyerCampaignApproved).to.equal(0);
    }

    await zestyMarket.sellerNFTDeposit(1, 1);

    atsList = [timeNow + 500, timeNow + 500, timeNow + 500];
    ateList = [timeNow + 10500, timeNow + 10500, timeNow + 10500];
    ctsList = [timeNow + 501, timeNow + 501, timeNow + 501];
    cteList = [timeNow + 10501, timeNow + 10501, timeNow + 10501];
    priceList = [100, 100, 100]

    await zestyMarket.sellerAuctionCreateBatch(
      1,
      atsList,
      ateList,
      ctsList,
      cteList,
      priceList
    );

    for (let i=4; i<=6; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(signers[0].address);
      expect(data.tokenId).to.equal(1);
      expect(data.auctionTimeStart).to.equal(timeNow + 500);
      expect(data.auctionTimeEnd).to.equal(timeNow + 10500);
      expect(data.contractTimeStart).to.equal(timeNow + 501);
      expect(data.contractTimeEnd).to.equal(timeNow + 10501);
      expect(data.priceStart).to.equal(100);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(0);
      expect(data.buyerCampaign).to.equal(0);
      expect(data.buyerCampaignApproved).to.equal(1);
    }

    data = await zestyMarket.getSellerNFTSetting(1);
    expect(data.tokenId).to.equal(1);
    expect(data.seller).to.equal(signers[0].address);
    expect(data.autoApprove).to.equal(1);
    expect(data.inProgressCount).to.equal(3);

    await time.increase(200);

    await zestyMarket.sellerAuctionCancelBatch([4,5,6]);

    for (let i=4; i<=6; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(ethers.constants.AddressZero);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(0);
      expect(data.auctionTimeEnd).to.equal(0);
      expect(data.contractTimeStart).to.equal(0);
      expect(data.contractTimeEnd).to.equal(0);
      expect(data.priceStart).to.equal(0);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(0);
      expect(data.buyerCampaign).to.equal(0);
      expect(data.buyerCampaignApproved).to.equal(0);
    }
  });

  it('[batched] It should not allow a buyer to bid on the ad when banned.', async function() {
    // create campaignj
    await zestyMarket.connect(signers[1]).buyerCampaignCreate('testUri');

    // Deposit NFT
    await zestyMarket.sellerNFTDeposit(0, 2);

    await zestyMarket.authorizeOperator(signers[2].address);
    await zestyMarket.connect(signers[1]).authorizeOperator(signers[2].address);

    let atsList = [timeNow + 100, timeNow + 100, timeNow + 100];
    let ateList = [timeNow + 10000, timeNow + 10000, timeNow + 10000];
    let ctsList = [timeNow + 101, timeNow + 101, timeNow + 101];
    let cteList = [timeNow + 10001, timeNow + 10001, timeNow + 10001];
    let priceList = [100, 100, 100];

    await zestyMarket.sellerAuctionCreateBatch(
      0,
      atsList,
      ateList,
      ctsList,
      cteList,
      priceList
    );

    await zestyMarket.sellerBan(signers[1].address);

    await time.increase(200);

    await expect(zestyMarket.connect(signers[1]).sellerAuctionBidBatch([1,2,3], 1)).to.be.reverted;
    await expect(zestyMarket.connect(signers[2]).sellerAuctionBidBatch([1,2,3], 1)).to.be.reverted;

    await zestyMarket.sellerUnban(signers[1].address);


    await zestyMarket.connect(signers[2]).sellerAuctionBidBatch([1,2,3], 1);

    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(signers[0].address);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(timeNow + 100);
      expect(data.auctionTimeEnd).to.equal(timeNow + 10000);
      expect(data.contractTimeStart).to.equal(timeNow + 101);
      expect(data.contractTimeEnd).to.equal(timeNow + 10001);
      expect(data.priceStart).to.equal(100);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(98);
      expect(data.buyerCampaign).to.equal(1);
      expect(data.buyerCampaignApproved).to.equal(2);
    }

    // seller cannot withdraw token after bidding happened
    await expect(zestyMarket.sellerNFTWithdraw(0)).to.be.reverted;
  });

  it('[batched] It should give the owner and buyer the correct cut if the auction is rejected.', async function() {
    await expect(zestyMarket.connect(signers[2]).setZestyCut(100)).to.be.reverted;
    await zestyMarket.setZestyCut(100);
    expect(await zestyMarket.getZestyCut()).to.equal(100);

    // create campaign
    await zestyMarket.connect(signers[1]).buyerCampaignCreate('testUri');

    // Deposit NFT
    await zestyMarket.sellerNFTDeposit(0, 1);

    let atsList = [timeNow + 100, timeNow + 100, timeNow + 100];
    let ateList = [timeNow + 10000, timeNow + 10000, timeNow + 10000];
    let ctsList = [timeNow + 101, timeNow + 101, timeNow + 101];
    let cteList = [timeNow + 10001, timeNow + 10001, timeNow + 10001];
    let priceList = [1000, 1000, 1000];

    await zestyMarket.sellerAuctionCreateBatch(
      0,
      atsList,
      ateList,
      ctsList,
      cteList,
      priceList
    );

    await expect(zestyMarket.connect(signers[1]).sellerAuctionBidBatch([1,2,3], 1)).to.be.reverted;

    await time.increase(200);

    await zestyMarket.connect(signers[1]).sellerAuctionBidBatch([1,2,3], 1);

    data = await zestyToken.balanceOf(signers[0].address);
    expect(data).to.equal('99999999999999999999700000');

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(97039);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(2961);

    // seller cannot withdraw token after bidding happened
    await expect(zestyMarket.sellerNFTWithdraw(0)).to.be.reverted;

    // seller cannot cancel once there's a bid
    await expect(zestyMarket.sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    await zestyMarket.sellerAuctionRejectBatch([1,2,3]);

    data = await zestyToken.balanceOf(signers[0].address);
    expect(data).to.equal('99999999999999999999700027');

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(99973);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(0);

    // allow cancellation and withdrawal of NFT once rejection occured
    await zestyMarket.sellerAuctionCancelBatch([1,2,3]);
    for (let i=1; i<=3; i++) {
      data = await zestyMarket.getSellerAuction(i);
      expect(data.seller).to.equal(ethers.constants.AddressZero);
      expect(data.tokenId).to.equal(0);
      expect(data.auctionTimeStart).to.equal(0);
      expect(data.auctionTimeEnd).to.equal(0);
      expect(data.contractTimeStart).to.equal(0);
      expect(data.contractTimeEnd).to.equal(0);
      expect(data.priceStart).to.equal(0);
      expect(data.pricePending).to.equal(0);
      expect(data.priceEnd).to.equal(0);
      expect(data.buyerCampaign).to.equal(0);
      expect(data.buyerCampaignApproved).to.equal(0);
    }

    await expect(zestyMarket.sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    await zestyMarket.sellerNFTWithdraw(0);
    data = await zestyMarket.getSellerNFTSetting(0);
    expect(data.tokenId).to.equal(0);
    expect(data.seller).to.equal(ethers.constants.AddressZero);
    expect(data.autoApprove).to.equal(0);
    expect(data.inProgressCount).to.equal(0);

    expect(await zestyNFT.ownerOf(0)).to.equal(signers[0].address);
  });

  it('[batched] It should give the owner and seller the correct cut if the contract is withdrawn.', async function() {
    await expect(zestyMarket.connect(signers[2]).setZestyCut(100)).to.be.reverted;
    await zestyMarket.setZestyCut(100);
    expect(await zestyMarket.getZestyCut()).to.equal(100);

    // create campaign
    await zestyMarket.connect(signers[1]).buyerCampaignCreate('testUri');

    // Deposit NFT
    await zestyMarket.connect(signers[3]).sellerNFTDeposit(2, 2);

    let atsList = [timeNow + 100, timeNow + 100, timeNow + 100];
    let ateList = [timeNow + 10000, timeNow + 10000, timeNow + 10000];
    let ctsList = [timeNow + 101, timeNow + 101, timeNow + 101];
    let cteList = [timeNow + 10001, timeNow + 10001, timeNow + 10001];
    let priceList = [1000, 1000, 1000];

    await zestyMarket.connect(signers[3]).sellerAuctionCreateBatch(
      2,
      atsList,
      ateList,
      ctsList,
      cteList,
      priceList
    );

    await expect(zestyMarket.connect(signers[1]).sellerAuctionBidBatch([1,2,3], 1)).to.be.reverted;

    await time.increase(200);

    await zestyMarket.connect(signers[1]).sellerAuctionBidBatch([1,2,3], 1);

    data = await zestyToken.balanceOf(signers[0].address);
    expect(data).to.equal('99999999999999999999700000');

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(97039);

    data = await zestyToken.balanceOf(signers[3].address);
    expect(data).to.equal(100000);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(2961);

    // seller cannot withdraw token after bidding happened
    await expect(zestyMarket.connect(signers[3]).sellerNFTWithdraw(0)).to.be.reverted;

    // seller cannot cancel once there's a bid
    await expect(zestyMarket.connect(signers[3]).sellerAuctionCancelBatch([1,2,3])).to.be.reverted;

    await time.increase(10000);

    await zestyMarket.connect(signers[3]).contractWithdrawBatch([1,2,3]);

    data = await zestyToken.balanceOf(signers[0].address);
    expect(data).to.equal('99999999999999999999700027');

    data = await zestyToken.balanceOf(signers[1].address);
    expect(data).to.equal(97039);

    data = await zestyToken.balanceOf(signers[3].address);
    expect(data).to.equal(102934);

    data = await zestyToken.balanceOf(zestyMarket.address);
    expect(data).to.equal(0);

  });
});
