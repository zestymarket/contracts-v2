certoraRun contracts/market/ZestyNFT.sol \
    --verify ZestyNFT:specs/market/nft.spec \
    --optimistic_loop --loop_iter 2 \
    --cache zesty_nft \
    --rule_sanity \
    --rule $1 --settings -deleteSMTFile=false,-postProcessCounterExamples=true
