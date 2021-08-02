certoraRun contracts/market/ZestyMarket_ERC20_V1_1.sol \
	--verify ZestyMarket_ERC20_V1_1:specs/sanity.spec \
	--optimistic_loop --loop_iter 2 \
	--msg "Sanity Market v1_1"
