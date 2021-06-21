certoraRun contracts/market/ZestyMarket_ERC20_V2.sol \
	--verify ZestyMarket_ERC20_V2:specs/privileged.spec \
	--optimistic_loop --loop_iter 3 \
	--msg "Privileged Market v2"
