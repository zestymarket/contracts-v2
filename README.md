# Zesty Contracts v2
Zesty Market is a set of smart contracts that allow creators to tokenize digital spaces (example, stream overlays for streaming platforms like Twitch, digital spaces on games) in the form of Non-fungible Tokens (NFTs). 

These NFTs can be rented out through a marketplace which allows advertisers to purchase a timeslot to advertise. Price discovery is done through a Dutch auction.

With this mechanism, Zesty Market allows creators to create digital assets that are able to generate revenue. 
Such NFTs can act as financial assets to support underwriting, giving creators a way of taking on loans, or insurance to support their creative endeavors.

Advertisers, are able to advertise in a trustless way. 
Advertisers can be sure that their ad spend has not be siphoned resulting in lost reach, and be sure that creators have received the ad monies directly.
With the transparent advertising mechanism, advertisers are able to build partnerships with creators instead of solely advertising in a blackbox. 
This allows advertisers to obtain valuable reach and allies in a way that goes beyond analytics.

# Quickstart
1. This repository is built with hardhat. First, install hardhat with npx
```
$ npx hardhat
```

2. Create a `.env` file with the following information.

`INFURA_PROJECT_ID` is the key to your infura account. This will be needed if you would want to deploy the contract on public mainnets or testnets. 

`PRIVATE_KEY` is the key to an ethereum account that would be used for deployment on mainnets or testnets. Make sure to keep this key safely. For added security ensure that this key only contain sufficient funds for interaction with the mainnnets.
```
INFURA_PROJECT_ID=<Get this from infura.io>
PRIVATE_KEY=<Get this from your eth account>
```

3. General hardhat commands to compile, test, and run
```
npx hardhat compile
npx hardhat test
npx hardhat run scripts/deploy-local.js --network ganache // local deploy
npx hardhat run scripts/deploy.js --network rinkeby  // rinkeby deploy
```

4. Details to use the local hardhat on metamask
```
Network Name: Hardhat (or anything you want)
New RPC URL: http://localhost:8545
Chain ID: 31337
Currency Symbol: DEV (or anything you want)
Block Explorer: (Leave Blank, alternatively)
```


# Contracts

Documentation about the contracts can be found on our [documentation site https://docs.zesty.market](https://docs.zesty.market/smart-contracts/overview)

## References
- Code in `utils` and `interfaces` are adapted from [openzeppelin-contracts-v3.4](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/release-v3.4/contracts)

- Code in `governance` is adapted from [compound](https://github.com/compound-finance/compound-protocol)


## Scratch Documentation

### ZestyToken.sol
ZestyToken, $ZEST, is both a governance token as well as a utility token. 
As a Governance token, $ZEST can be used for voting on key decisions in the ZestyDAO.
As a Utility token, $ZEST can be used in transactions within Zesty Market.

**Specifications**

### ZestyNFT.sol
ZestyNFT is the contract which allows a creator to declare advertising slots that can be subsequently rented out. 

These NFTs can be deposited in the ZestyMarket contracts for rent. 
The NFTs would accrue $ZEST upon successful auctions. 
This creates a price floor for the NFTs which allows the NFTs to serve as collateral or be used for underwriting in future.

**Addresses**
```
Rinkeby: 0xa6fC03b3343D72630db8767B179C90b0ccd61354
```

**Specifications**

### ZestyVault.sol
ZestyVault is the abstract contract that is inherited by contracts like ZestyMarket to allow for the deposit of ZestyNFTs. Operators can be associated with an address to automate contract interactions.

### ZestyMarket_ERC20_V1.sol
Zesty Market is the key contract where you can auction out advertising slots as a creator and create advertising campaigns as an advertiser. 

**Addresses**
```
Rinkeby (USDC Compound): 0xD6551e7CD4DBbaf4F9186665Faa7A869868DC73e
```

**Specifications**

### StreamGame_ETH.sol
StreamGame_ETH is designed to receive donations while a streamer is streaming. The events generated would trigger some screen overlay to encourage viewer engagement.

**Addresses**
```
Rinkeby: 0x4F170B8F6939c4aEe8d32B264628Ae64478c5804
Matic: 0x3943C890D2ff687714358006DECA47B8809bF34D
```

**Specifications**

### ZestyDice_ETH.sol
ZestyDice_ETH is an extension of StreamGame but focused on dice games on stream.
Like StreamGame_ETH it allows the streamer to receive donations while streaming.

**Addresses**
```
Rinkeby: 0x308529F5A5aCCe53415A2a279175db6Be869439E
Matic: 0x40eFB3a83897fE06b6b3B339dB878C1ee4620788
```