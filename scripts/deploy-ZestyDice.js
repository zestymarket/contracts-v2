const hre = require("hardhat");

async function main() {
  signers = await ethers.getSigners();

  const ZestyDice = await hre.ethers.getContractFactory("ZestyDice_ETH");
  const zestyDice = await ZestyDice.deploy();
  await zestyDice.deployed();
  console.log("ZestyDice_ETH deployed to:", zestyDice.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
