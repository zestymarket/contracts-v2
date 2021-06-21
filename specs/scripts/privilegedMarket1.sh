certoraRun contracts/market/ZestyMarket_ERC20_V1_1.sol \
	--verify ZestyMarket_ERC20_V1_1:specs/privileged.spec \
	--optimistic_loop --loop_iter 2 \
	--msg "Privileged Market v1_1"
