transferDelegates(address src, address dst, uint amount) {
    env e0;
    env e1;
    require e1.block.number > e0.block.number;

    address srcRep = sinvoke delegates(e0, src);
    address dstRep = sinvoke delegates(e0, dst);

    uint srcBalancePrior = sinvoke balanceOf(e0, src);
    uint dstBalancePrior = sinvoke balanceOf(e0, dst);

    uint srcVotesPrior = sinvoke getCurrentVotes(e0, srcRep);
    uint dstVotesPrior = sinvoke getCurrentVotes(e0, dstRep);

    // Bound the number of checkpoints to prevent solver timeout / unwinding assertion violation
    uint32 nCheckpoints;
    require nCheckpoints == 1; // XXX
    require invoke numCheckpoints(e0, srcRep) == nCheckpoints && invoke numCheckpoints(e0, dstRep) == nCheckpoints;

    // Ensure the checkpoints are sane
    require sinvoke certoraOrdered(e0, src);
    require sinvoke certoraOrdered(e0, dst);
    require srcVotesPrior >= srcBalancePrior;
    require dstVotesPrior >= dstBalancePrior;

    require amount <= 79228162514264337593543950335; // UInt96 Max
    bool didTransfer = invoke transferFrom(e0, src, dst, amount);
    bool transferReverted = lastReverted;
    assert didTransfer || transferReverted, "Transfer either succeeds or reverts";

    uint srcBalancePost = sinvoke balanceOf(e1, src);
    uint dstBalancePost = sinvoke balanceOf(e1, dst);
    assert !transferReverted => (
        (src != dst) => ((dstBalancePost == dstBalancePrior + amount) && (srcBalancePost == srcBalancePrior - amount)) &&
        (src == dst) => ((dstBalancePost == dstBalancePrior) && (srcBalancePost == srcBalancePrior))
    ), "Transfers right amount";

    uint srcVotesPost = sinvoke getCurrentVotes(e1, srcRep);
    uint dstVotesPost = sinvoke getCurrentVotes(e1, dstRep);

    assert (srcRep == 0 && dstRep != 0 && !transferReverted) => (dstVotesPost == dstVotesPrior + amount), "Votes are created from the abyss";
    assert (srcRep != 0 && dstRep == 0 && !transferReverted) => (srcVotesPost + amount == srcVotesPrior), "Votes are destroyed into the abyss";
    assert (srcRep != 0 && dstRep != 0) => (srcVotesPrior + dstVotesPrior == srcVotesPost + dstVotesPost), "Votes are neither created nor destroyed";
}

binarySearch(address account, uint blockNumber, uint futureBlock) {
    env e0;
    require e0.msg.value == 0;
    require blockNumber < e0.block.number;
    require futureBlock >= e0.block.number;

    uint nCheckpoints;
    require nCheckpoints <= 4;
    require invoke numCheckpoints(e0, account) == nCheckpoints;

    require invoke certoraOrdered(e0, account);

    invoke getPriorVotes(e0, account, futureBlock);
    assert lastReverted, "Must revert for future blocks";

    uint votesLinear = invoke certoraScan(e0, account, blockNumber);
    assert !lastReverted, "Linear scan should not revert for any valid block number";

    uint votesBinary = invoke getPriorVotes(e0, account, blockNumber);
    assert !lastReverted, "Query should not revert for any valid block number";

    assert votesLinear == votesBinary, "Linear search and binary search disagree";
}