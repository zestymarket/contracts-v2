const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('CitrusCollectibles', function() {
  let citrus;
  let signers;
  let provider;

  beforeEach(async () => {
    signers = await ethers.getSigners();
    provider = signers[0].provider;

    const Citrus = await ethers.getContractFactory('CitrusCollectibles');
    citrus = await Citrus.deploy(
      signers[0].address,
      'https://example.com'
    );
    await citrus.deployed();
  });

  it("All onlyOwner functions can only be executed by owner", async function() {
     await expect(citrus.connect(signers[3]).pause()).to.be.reverted;
     await expect(citrus.connect(signers[3]).unpause()).to.be.reverted;
     await expect(citrus.connect(signers[3]).mint(
       signers[0].address,
       0,
       5,
       ""
     )).to.be.reverted;
     await expect(citrus.connect(signers[3]).mintBatch(
       signers[0].address,
       [0],
       [5],
       ""
     )).to.be.reverted;
     await expect(citrus.connect(signers[3]).burn(
       signers[0].address,
       0,
       5,
     )).to.be.reverted;
     await expect(citrus.connect(signers[3]).burnBatch(
       signers[0].address,
       [0],
       [5],
     )).to.be.reverted;
     await expect(citrus.connect(signers[3]).setURI('new')).to.be.reverted;

     await citrus.transferOwnership(signers[3].address);
     await expect(citrus.connect(signers[0]).pause()).to.be.reverted;
     await expect(citrus.connect(signers[0]).unpause()).to.be.reverted;
     await expect(citrus.connect(signers[0]).mint(
       signers[0].address,
       0,
       5,
       ""
     )).to.be.reverted;
     await expect(citrus.connect(signers[0]).mintBatch(
       signers[0].address,
       [0],
       [5],
       ""
     )).to.be.reverted;
     await expect(citrus.connect(signers[0]).burn(
       signers[0].address,
       0,
       5,
     )).to.be.reverted;
     await expect(citrus.connect(signers[0]).burnBatch(
       signers[0].address,
       [0],
       [5],
     )).to.be.reverted;
     await expect(citrus.connect(signers[0]).setURI('new')).to.be.reverted;
  });

  it("Allows owner to mint and transfer tokens and burn tokens not within possession", async function() {
    await citrus.mint(signers[0].address, 0, 2, "0x00");
    await citrus.mintBatch(signers[0].address, [0], [3], "0x00");
    let balance = await citrus.balanceOf(signers[0].address, 0);
    expect(balance).to.equal(5);

    // transfer token

    // Sanity checks
    await expect(citrus.connect(signers[1]).safeTransferFrom(
      signers[1].address,
      signers[2].address,
      0,
      1,
      "0x00"
    )).to.be.reverted;
    await expect(citrus.connect(signers[1]).safeBatchTransferFrom(
      signers[1].address,
      signers[2].address,
      [0],
      [1],
      "0x00"
    )).to.be.reverted;

    await citrus.connect(signers[0]).safeTransferFrom(
      signers[0].address,
      signers[1].address,
      0,
      2,
      "0x00"
    );
    await citrus.connect(signers[0]).safeBatchTransferFrom(
      signers[0].address,
      signers[1].address,
      [0],
      [3],
      "0x00"
    );

    balance = await citrus.balanceOf(signers[1].address, 0);
    expect(balance).to.equal(5);

    await expect(citrus.connect(signers[0]).safeTransferFrom(
      signers[0].address,
      signers[1].address,
      0,
      2,
      "0x00"
    )).to.be.reverted;
    await expect(citrus.connect(signers[0]).safeBatchTransferFrom(
      signers[0].address,
      signers[1].address,
      [0],
      [3],
      "0x00"
    )).to.be.reverted;

    // burn tokens
    await citrus.connect(signers[0]).burn(
      signers[1].address,
      0,
      2
    );
    await citrus.connect(signers[0]).burnBatch(
      signers[1].address,
      [0],
      [3],
    );

    balance = await citrus.balanceOf(signers[1].address, 0);
    expect(balance).to.equal(0);
  });

  it("Only allow owner to set uri", async function() {
    await citrus.connect(signers[0]).setURI("new3");
    uri = await citrus.uri(0);
    expect(uri).to.equal('new3');
  });

  it("Prevent transfer of assets if system is paused", async function() {
    await citrus.mint(signers[0].address, 0, 2, "0x00");
    await citrus.mintBatch(signers[0].address, [0], [3], "0x00");
    await citrus.pause();
    await expect(citrus.pause()).to.be.reverted;
    await expect(citrus.connect(signers[0]).safeTransferFrom(
      signers[0].address,
      signers[1].address,
      0,
      1,
      "0x00"
    )).to.be.reverted;
    await expect(citrus.connect(signers[0]).safeBatchTransferFrom(
      signers[0].address,
      signers[1].address,
      [0],
      [1],
      "0x00"
    )).to.be.reverted;
    await citrus.unpause();
    await expect(citrus.unpause()).to.be.reverted;
    await citrus.connect(signers[0]).safeTransferFrom(
      signers[0].address,
      signers[1].address,
      0,
      1,
      "0x00"
    );
    await citrus.connect(signers[0]).safeBatchTransferFrom(
      signers[0].address,
      signers[1].address,
      [0],
      [1],
      "0x00"
    );
    let balance = await citrus.balanceOf(signers[1].address, 0);
    expect(balance).to.equal(2);
  });
});
