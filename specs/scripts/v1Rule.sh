certoraRun specs/harness/V1Harness.sol \
    --verify V1Harness:specs/market/v1.spec \
    --optimistic_loop --loop_iter 2 \
    --rule $1 \
    --msg "Market V1 $1"