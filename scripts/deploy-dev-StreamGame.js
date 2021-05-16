const hre = require("hardhat");

async function main() {
  signers = await ethers.getSigners();

  const StreamGame = await hre.ethers.getContractFactory("StreamGame_ETH");
  const streamGame = await StreamGame.deploy();
  await streamGame.deployed();
  console.log("StreamGame_ETH deployed to:", streamGame.address);

  await streamGame.start();

  // Donate
  await streamGame.connect(signers[1]).donate(1, 'test', {value: 1000});
  
  await streamGame.connect(signers[2]).donate(1, 'test2', {value: 2000});

  await streamGame.connect(signers[3]).donate(1, 'test3', {value: 3000});

  await streamGame.connect(signers[1]).donate(1, 'test1', {value: 1000});

  // Withdraw
  await streamGame.connect(signers[3]).withdraw(ethers.BigNumber.from(1));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
