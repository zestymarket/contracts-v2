certoraRun contracts/market/ZestyMarket_ERC20_V2.sol \
	--verify ZestyMarket_ERC20_V2:specs/sanity.spec \
	--optimistic_loop --loop_iter 3 \
	--msg "Sanity Market v2"
