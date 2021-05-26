const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('ZestyMarket_ERC20_V1', function() {
  let streamGame;
  let signers;

  beforeEach(async () => {
    signers = await ethers.getSigners();

    const ZestyToken = await ethers.getContractFactory('ZestyToken');
    zestyToken = await ZestyToken.deploy();
    await zestyToken.deployed();

    const ZestyNFT = await ethers.getContractFactory('ZestyNFT');
    zestyNFT = await ZestyNFT.deploy(zestyToken.address);
    await zestyNFT.deployed();

    const ZestyMarket = await ethers.getContractFactory('ZestyMarket_ERC20_V1');
    zestyMarket = await ZestyMarket.deploy(zestyToken.address, zestyNFT.address);
    await zestyMarket.deployed();

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
});
