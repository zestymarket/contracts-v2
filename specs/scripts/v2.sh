certoraRun.py specs/harness/V2Harness.sol contracts/market/ZestyNFT.sol specs/harness/DummyERC20A.sol specs/harness/DummyERC721Receiver.sol \
    --link V2Harness:_txToken=DummyERC20A \
    --link V2Harness:_zestyNFT=ZestyNFT \
    --verify V2Harness:specs/market/v2.spec \
    --optimistic_loop --loop_iter 2 \
    --cache zesty \
    --msg "Market V2" \
    --staging shelly/preferIteAsExprInHavocAssuming 
