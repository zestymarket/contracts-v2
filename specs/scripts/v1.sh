certoraRun specs/harness/V1Harness.sol specs/harness/DummyERC20A.sol \
    --link V1Harness:_txToken=DummyERC20A \
    --verify V1Harness:specs/market/v1.spec \
    --optimistic_loop --loop_iter 2 \
    --cache zesty \
    --msg "Market V1"