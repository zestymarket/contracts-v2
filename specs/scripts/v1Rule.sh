certoraRun specs/harness/V1Harness.sol contracts/market/ZestyNFT.sol specs/harness/DummyERC20A.sol specs/harness/DummyERC721Receiver.sol \
    --link V1Harness:_txToken=DummyERC20A \
    --link V1Harness:_zestyNFT=ZestyNFT \
    --verify V1Harness:specs/market/v1.spec \
    --optimistic_loop --loop_iter 2 \
    --rule $1 \
    --cache zesty \
    --msg "Market V1 $1 $2" 
