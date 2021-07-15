
# Simplify ZestyNFT

perl -0777 -i -pe 's/constructor\(/function safeTransferFrom\(address from, address to, uint256 tokenId, bytes memory _data\) public virtual override \{\}\n constructor \(/g' contracts/market/ZestyNFT.sol