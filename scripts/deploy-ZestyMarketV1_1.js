const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
  // rinkeby usdc address 
  // let ERC20Address = "0x4dbcdf9b62e891a7cec5a2568c3f4faf9e8abe2b";

  // ethereum mainnet usdc address
  // let ERC20Address = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

  // matic usdc address
  let ERC20Address = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";

  const ZestyNFT = await hre.ethers.getContractFactory("ZestyNFT");
  const zestyNFT = await ZestyNFT.deploy(
    "0xB0270654a0158c8aD52a955f7Fd399474B2107a5", 
    ethers.constants.AddressZero
  );
  await zestyNFT.deployed();
  console.log("ZestyNFT deployed to:", zestyNFT.address);

  const ZestyMarket = await hre.ethers.getContractFactory("ZestyMarket_ERC20_V1_1");
  const zestyMarket = await ZestyMarket.deploy(ERC20Address, zestyNFT.address);
  await zestyMarket.deployed();
  console.log("ZestyMarket_ERC20_V1_1 deployed to:", zestyMarket.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
