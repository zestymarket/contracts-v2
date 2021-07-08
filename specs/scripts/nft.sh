certoraRun.py contracts/market/ZestyNFT.sol \
    --verify ZestyNFT:specs/market/nft.spec \
    --optimistic_loop --loop_iter 2 \
    --cache zesty_nft \
    --rule_sanity \
    --msg "ZestyNFT" \
    --staging shelly/robustnessAndCalldatasize
