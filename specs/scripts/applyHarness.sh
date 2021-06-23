# Remove emits (including multiline)
perl -0777 -i -pe 's/(emit \w+\(([a-zA-Z0-9_.,]*\s*)*\));/\/\*\1   ;\*\//g' contracts/market/ZestyMarket_ERC20_V1_1.sol