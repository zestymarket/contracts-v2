certoraRun specs/harness/V1Harness.sol \
    --verify V1Harness:specs/market/v1.spec \
    --optimistic_loop --loop_iter 2 \
    --msg "Market V1"