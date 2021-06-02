const hre = require("hardhat");
const { ethers } = require("hardhat");
const { time } = require('@openzeppelin/test-helpers');

async function main() {
  const signers = await ethers.getSigners();
  let timeNow = await time.latest();
  timeNow = timeNow.toNumber();

  const ZestyToken = await hre.ethers.getContractFactory("ZestyToken");
  const zestyToken = await ZestyToken.deploy();
  await zestyToken.deployed();
  console.log("ZestyToken deployed to:", zestyToken.address);

  const ZestyNFT = await hre.ethers.getContractFactory("ZestyNFT");
  const zestyNFT = await ZestyNFT.deploy(ethers.constants.AddressZero);
  await zestyNFT.deployed();
  console.log("ZestyNFT deployed to:", zestyNFT.address);

  const ZestyMarket = await hre.ethers.getContractFactory("ZestyMarket_ERC20_V1");
  const zestyMarket = await ZestyMarket.deploy(zestyToken.address, zestyNFT.address);
  await zestyMarket.deployed();
  console.log("ZestyMarket_ERC20_V1 deployed to:", zestyMarket.address);

  await zestyNFT.mint('testUri');
  await zestyNFT.mint('testUri1');
  await zestyNFT.mint('testUri2');
  await zestyNFT.approve(zestyMarket.address, 0);
  await zestyToken.approve(zestyMarket.address, 100000000);
  await zestyToken.transfer(signers[1].address, 100000);
  await zestyToken.connect(signers[1]).approve(zestyMarket.address, 100000000);
  await zestyToken.transfer(signers[2].address, 100000);
  await zestyToken.connect(signers[2]).approve(zestyMarket.address, 100000000);
  await zestyToken.transfer(signers[3].address, 100000);
  await zestyToken.connect(signers[3]).approve(zestyMarket.address, 100000000);

  await zestyMarket.connect(signers[1]).buyerCampaignCreate('testUri');

  await zestyMarket.sellerNFTDeposit(0, 2);

  await zestyMarket.sellerAuctionCreate(
    0,
    timeNow + 100,
    timeNow + 10000,
    timeNow + 101,
    timeNow + 10001,
    100
  );

  await time.increase(200);

  await zestyMarket.connect(signers[1]).sellerAuctionBid(1, 1)

  time.increase(10050);

  await zestyMarket.contractWithdraw(1);

  await zestyMarket.sellerNFTWithdraw(0);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
