const hre = require("hardhat");

async function main() {
  signers = await ethers.getSigners();

  const ZestyDice = await hre.ethers.getContractFactory("ZestyDice_ETH");
  const zestyDice = await ZestyDice.deploy(); await zestyDice.deployed();
  console.log("ZestyDice_ETH deployed to:", zestyDice.address);

  await zestyDice.start();

  // Donate
  await zestyDice.connect(signers[1]).donate(1, 'test', {value: 1000});
  
  await zestyDice.connect(signers[2]).donate(1, 'test2', {value: 2000});

  await zestyDice.connect(signers[3]).donate(1, 'test3', {value: 3000});

  await zestyDice.connect(signers[1]).donate(1, 'test1', {value: 1000});

  // Withdraw
  await zestyDice.connect(signers[3]).withdraw(ethers.BigNumber.from(1));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
