# Remove emits (including multiline)
perl -0777 -i -pe 's/(emit \w+\(([a-zA-Z0-9_.,]*\s*)*\));/\/\*\1   ;\*\//g' contracts/market/ZestyMarket_ERC20_V1_1.sol

perl -0777 -i -pe 's/(emit \w+\(([a-zA-Z0-9_.,]*\s*)*\));/\/\*\1   ;\*\//g' contracts/market/ZestyMarket_ERC20_V2.sol

# Simplify price function
perl -0777 -i -pe 's/function getSellerAuctionPrice\(/mapping \(uint256 => mapping \(uint256 => uint256\)\) priceFunction;

function     getSellerAuctionPrice\(uint256 _sellerAuctionId\) public view returns \(uint256\) \{
    return priceFunction\[_sellerAuctionId\]\[block.timestamp\];
\}

function getSellerAuctionPriceOriginal\(/g' contracts/market/ZestyMarket_ERC20_V1_1.sol

perl -0777 -i -pe 's/function getSellerAuctionPrice\(/mapping \(uint256 => mapping \(uint256 => uint256\)\) priceFunction;

function     getSellerAuctionPrice\(uint256 _sellerAuctionId\) public view returns \(uint256\) \{
    return priceFunction\[_sellerAuctionId\]\[block.timestamp\];
\}

function getSellerAuctionPriceOriginal\(/g' contracts/market/ZestyMarket_ERC20_V2.sol

# Simplify ZestyNFT

perl -0777 -i -pe 's/constructor\(/function safeTransferFrom\(address from, address to, uint256 tokenId, bytes memory _data\) public virtual override \{\}\n constructor \(/g' contracts/market/ZestyNFT.sol