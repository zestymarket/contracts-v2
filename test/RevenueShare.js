const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('RevenueShare', function() {
  let token;
  let zestyNFT;
  let zestyMarket;
  let zestySplitMain;
  let zestySplitWallet;
  let signers;
  let provider;

  beforeEach(async () => {
    signers = await ethers.getSigners();
    provider = signers[0].provider;

    const Token = await ethers.getContractFactory("ZestyToken");
    token = await Token.deploy(signers[0].address);
    await token.deployed();

    const ZestyNFT = await ethers.getContractFactory('ZestyNFT');
    zestyNFT = await ZestyNFT.deploy(
      signers[0].address,
      token.address
    );
    await zestyNFT.deployed();

    const ZestyMarket = await ethers.getContractFactory('ZestyMarket')
    zestyMarket = await ZestyMarket.deploy(
      token.address,
      zestyNFT.address,
      signers[0].address
    );
    await zestyMarket.deployed();

    const ZestySplitMain = await ethers.getContractFactory('ZestySplitMain');
    zestySplitMain = await ZestySplitMain.deploy(
      zestyMarket.address,
      token.address,

    );
    await zestySplitMain.deployed();
  });
});