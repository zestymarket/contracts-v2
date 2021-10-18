const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('ZestyCommissions_ERC20_V1_1', function() {
  let token;
  let nft;
  let market;
  let comm;
  let signers;
  let provider;

  beforeEach(async () => {
    signers = await ethers.getSigners();
    provider = signers[0].provider;

    let Token = await ethers.getContractFactory('ZestyToken');
    token = await Token.deploy(signers[0].address);
    await token.deployed();

    let NFT = await ethers.getContractFactory('ZestyNFT');
    nft = await NFT.deploy(signers[0].address, token.address)
    await nft.deployed();

    let Market = await ethers.getContractFactory('ZestyMarket_ERC20_V1_1');
    market = await Market.deploy(
      token.address,
      nft.address,
      signers[0].address,
    );
    await market.deployed();

    const Commissions = await ethers.getContractFactory('ZestyCommissions_ERC20_V1_1');
    comm = await Commissions.deploy(
      token.address,
      nft.address,
      market.address,
    );
    await comm.deployed();

    await nft.mint('testUri');
    await nft.mint('testUri1');
    await nft.connect(signers[3]).mint('testUri2');
    await nft.approve(comm.address, 0);
    await nft.approve(comm.address, 1);
    await nft.connect(signers[3]).approve(comm.address, 2);
    await token.approve(market.address, 100000000);
    await token.transfer(signers[1].address, 100000);
    await token.connect(signers[1]).approve(market.address, 100000000);
    await token.transfer(signers[2].address, 100000);
    await token.connect(signers[2]).approve(market.address, 100000000);
    await token.transfer(signers[3].address, 100000);
    await token.connect(signers[3]).approve(market.address, 100000000);
  });

  it("It should allow a depositor to deposit a token successfully", async function() {
    await comm.sellerNFTDeposit(
      0,
      100,
      10,
      1,
    );

    expect(await nft.ownerOf(0)).to.equal(market.address);
  });

  it("It should give the depositor the specified number of share token", async function() {
    await comm.sellerNFTDeposit(
      0,
      100,
      10,
      1,
    );

    expect (await comm.getTokenId(1)).to.equal(0);
    expect (await comm.getDepositor(1)).to.equal(signers[0].address);
    expect(await comm.balanceOf(signers[0].address, 1)).to.equal(100);
  });

  it("The ERC1155 FT should have the same uri as deposited token", async function() {
    await comm.sellerNFTDeposit(
      0,
      100,
      10,
      1,
    );
    expect(await comm.uri(1)).to.equal('testUri');
  });
});
