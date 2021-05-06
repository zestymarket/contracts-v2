const hre = require("hardhat");

async function main() {
  signers = await ethers.getSigners();

  const ZestyNFT = await hre.ethers.getContractFactory("ZestyNFT");
  const zestyNFT = await ZestyNFT.deploy();
  await zestyNFT.deployed();
  console.log("ZestyNFT deployed to:", zestyNFT.address);

  const ZestyToken = await hre.ethers.getContractFactory("ZestyToken");
  const zestyToken = await ZestyToken.deploy();
  await zestyToken.deployed();
  console.log("ZestyToken deployed to:", zestyToken.address);

  const AuctionHTLC_ZEST = await hre.ethers.getContractFactory("AuctionHTLC_ZEST");
  const auctionHTLC_ZEST = await AuctionHTLC_ZEST.deploy(
    zestyToken.address,
    zestyNFT.address,
    signers[2].address
  );
  await auctionHTLC_ZEST.deployed();
  console.log("AuctionHTLC_ZEST deployed to:", auctionHTLC.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
