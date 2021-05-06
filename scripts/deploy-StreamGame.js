const hre = require("hardhat");

async function main() {
  signers = await ethers.getSigners();

  const StreamGame = await hre.ethers.getContractFactory("StreamGame_ETH");
  const streamGame = await StreamGame.deploy();
  await streamGame.deployed();
  console.log("StreamGame_ETH deployed to:", streamGame.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
