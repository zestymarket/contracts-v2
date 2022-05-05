const hre = require("hardhat");
const { ethers } = require("hardhat");
const { time } = require('@openzeppelin/test-helpers');

async function main() {
  const signers = await ethers.getSigners();
  let timeNow = await time.latest();
  timeNow = timeNow.toNumber();

  const ZestyToken = await hre.ethers.getContractFactory("ZestyToken");
  const zestyToken = await ZestyToken.deploy(signers[0].address);
  await zestyToken.deployed();
  console.log("ZestyToken deployed to:", zestyToken.address);

  const ZestyNFT = await hre.ethers.getContractFactory("ZestyNFT");
  const zestyNFT = await ZestyNFT.deploy(signers[0].address, ethers.constants.AddressZero);
  await zestyNFT.deployed();
  console.log("ZestyNFT deployed to:", zestyNFT.address);

  const ZestyMarket = await hre.ethers.getContractFactory("ZestyMarket_ERC20_V1_1");
  const zestyMarket = await ZestyMarket.deploy(zestyToken.address, zestyNFT.address, signers[0].address);
  await zestyMarket.deployed();
  console.log("ZestyMarket_ERC20_V1 deployed to:", zestyMarket.address);

  await zestyNFT.mint('testUri');
  await zestyNFT.mint('testUri1');
  await zestyNFT.transferFrom(signers[0].address, signers[1].address, 1);
  await zestyNFT.mint('testUri2');
  await zestyNFT.approve(zestyMarket.address, 0);
  await zestyToken.approve(zestyMarket.address, 100000000000);
  await zestyToken.transfer(signers[1].address, 100000000);
  await zestyToken.connect(signers[1]).approve(zestyMarket.address, 100000000000);
  await zestyToken.transfer(signers[2].address, 100000000);
  await zestyToken.connect(signers[2]).approve(zestyMarket.address, 100000000000);
  await zestyToken.transfer(signers[3].address, 100000000);
  await zestyToken.connect(signers[3]).approve(zestyMarket.address, 100000000000);

  await zestyMarket.connect(signers[1]).buyerCampaignCreate('testUri');

  await zestyMarket.sellerNFTDeposit(0, 1);

  await zestyMarket.sellerAuctionCreateBatch(
    0,
    [timeNow + 300],
    [timeNow + 10000],
    [timeNow + 301],
    [timeNow + 10001],
    [100]
  );

  await time.increase(500);

  await zestyMarket.connect(signers[1]).sellerAuctionBidBatch([1], 1);

  await zestyMarket.sellerAuctionRejectBatch([1]);

  await zestyMarket.connect(signers[1]).sellerAuctionBidBatch([1], 1);

  await zestyMarket.sellerAuctionApproveBatch([1]);

  time.increase(10050);

  await zestyMarket.contractWithdrawBatch([1]);

  await zestyMarket.sellerNFTWithdraw(0);

  timeNow = await time.latest();
  timeNow = timeNow.toNumber();

  await zestyNFT.connect(signers[1]).mint('testUri');
  await zestyNFT.connect(signers[1]).approve(zestyMarket.address, 3);
  await zestyMarket.connect(signers[1]).sellerNFTDeposit(3, 2);
  await zestyMarket.buyerCampaignCreate('testUri');

  await zestyMarket.connect(signers[1]).sellerAuctionCreateBatch(
    3,
    [timeNow + 300],
    [timeNow + 10000],
    [timeNow + 301],
    [timeNow + 10001],
    [100]
  );

  await time.increase(500);

  await zestyMarket.sellerAuctionBidBatch([2], 2);

  time.increase(10050);

  await zestyMarket.connect(signers[1]).contractWithdrawBatch([2]);

  await zestyNFT.approve(zestyMarket.address, 0);
  await zestyMarket.sellerNFTDeposit(0, 2);

  timeNow = await time.latest();
  timeNow = timeNow.toNumber();

  await zestyMarket.sellerAuctionCreateBatch(
    0,
    [timeNow + 300],
    [timeNow + 10000],
    [timeNow + 301],
    [timeNow + 10001],
    [100]
  );

  await time.increase(600);

  await zestyMarket.connect(signers[1]).sellerAuctionBidBatch([3], 1)

  time.increase(10050);

  await zestyMarket.contractWithdrawBatch([3]);

  timeNow = await time.latest();
  timeNow = timeNow.toNumber();

  await zestyNFT.connect(signers[2]).mint('testUri');
  await zestyNFT.connect(signers[2]).approve(zestyMarket.address, 4);
  await zestyMarket.connect(signers[2]).sellerNFTDeposit(4, 1);
  await zestyMarket.connect(signers[2]).sellerAuctionCreateBatch(
    4,
    [timeNow + 300, timeNow + 300],
    [timeNow + 10000, timeNow + 10000],
    [timeNow + 301, timeNow + 301],
    [timeNow + 10001, timeNow + 10001],
    [100, 100]
  );
  await time.increase(600);
  await zestyMarket.connect(signers[1]).sellerAuctionBidBatch([4], 1);

  await zestyNFT.connect(signers[2]).mint('testUri');
  await zestyNFT.connect(signers[2]).approve(zestyMarket.address, 5);
  await zestyMarket.connect(signers[2]).sellerNFTDeposit(5, 1);

  await zestyMarket.authorizeOperator(signers[1].address);
  await zestyMarket.connect(signers[2]).authorizeOperator(signers[3].address);

  await zestyMarket.revokeOperator(signers[1].address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
