validStatesAndTransitions(env e0, env e1) {
    // Possible states
    uint PENDING = 0;
    uint ACTIVE = 1;
    uint CANCELED = 2;
    uint DEFEATED = 3;
    uint SUCCEEDED = 4;
    uint QUEUED = 5;
    uint EXPIRED = 6;
    uint EXECUTED = 7;

    uint proposalId = sinvoke certoraPropose(e0);

    uint startBlock = invoke certoraProposalStart(e0, proposalId);
    uint endBlock = invoke certoraProposalEnd(e0, proposalId);
    uint state = invoke certoraProposalState(e0, proposalId);

    // XXX simulate calling any other (sequence of?) functions in between?
    //  do more specific paths of transitions based on this sequence?

    uint startBlockNext = invoke certoraProposalStart(e1, proposalId);
    uint endBlockNext = invoke certoraProposalEnd(e1, proposalId);
    uint stateNext = invoke certoraProposalState(e1, proposalId);

    require e1.block.number == e0.block.number + 1;
    assert startBlockNext == startBlock, "Start block may not change";
    assert endBlockNext == endBlock, "End block may not change";

    // Possibilities based on time

    assert (e0.block.number <= startBlock) => (
        state == CANCELED ||
        state == PENDING
     ), "Prior to voting, may only be pending or canceled";

    assert (e0.block.number > startBlock && e0.block.number <= endBlock) => (
        state == CANCELED ||
        state == ACTIVE
     ), "During voting, may only be active or canceled";

    assert (e0.block.number > endBlock) => (
        state == CANCELED ||
        state == DEFEATED ||
        state == SUCCEEDED ||
        state == QUEUED ||
        state == EXPIRED ||
        state == EXECUTED
     ), "After voting, must be in a viable state";

    // Allowed transitions

    assert (state == PENDING) => (
        (stateNext == CANCELED) ||
        (stateNext == ACTIVE && e1.block.number > startBlock) ||
        (stateNext == PENDING)
     ), "From pending, must either become canceled, active, or remain pending";

    assert (state == ACTIVE) => (
        (stateNext == CANCELED) ||
        ((
         stateNext == DEFEATED ||
         stateNext == SUCCEEDED ||
         stateNext == QUEUED ||
         stateNext == EXPIRED ||
         stateNext == EXECUTED
        ) && e1.block.number > endBlock) ||
        (stateNext == ACTIVE)
     ), "From active, must either become canceled, a viable next statem or remain active";

    assert (state == CANCELED) => (stateNext == CANCELED), "Once canceled, always canceled";

    assert (state == DEFEATED) => (
        stateNext == CANCELED ||
        stateNext == DEFEATED
     ), "From defeated, must either become canceled, or remain defeated";

    assert (state == SUCCEEDED) => (
        stateNext == CANCELED ||
        stateNext == QUEUED ||
        stateNext == SUCCEEDED
     ), "From succeeded, must either become canceled, queued, or remain expired";

    assert (state == QUEUED) => (
        stateNext == CANCELED ||
        stateNext == EXPIRED ||
        stateNext == EXECUTED ||
        stateNext == QUEUED
     ), "From queued, must either become canceled, expired, executed, or remain queued";

    assert (state == EXPIRED) => (
        stateNext == CANCELED ||
        stateNext == EXPIRED
     ), "From expired, must either become canceled, or remain expired";

    assert (state == EXECUTED) => (stateNext == EXECUTED), "Once executed, always executed";
}

voteOnce(uint proposalId, bool support) {
    env e0;
    env e1;
    require e0.msg.sender == e1.msg.sender;

    invoke castVote(e0, proposalId, support);
    bool firstVoteReverted = lastReverted;

    invoke castVote(e1, proposalId, support);
    bool secondVoteReverted = lastReverted;

    assert !firstVoteReverted => secondVoteReverted, "Second vote succeeded after first";
}

votesSum(uint proposalId, bool support, address voterA, address voterB) {
    // XXX I guess we can't really havoc proposalId?
    env e0;
    env e1;
    require e0.msg.sender == voterA;
    require e1.msg.sender == voterB;

    sinvoke castVote(e0, proposalId, support);
    sinvoke castVote(e1, proposalId, support);

    assert true; // XXX Shh
}

validStatesAndTransitions() {
    // Possible states
    uint PENDING = 0;
    uint ACTIVE = 1;
    uint CANCELED = 2;
    uint DEFEATED = 3;
    uint SUCCEEDED = 4;
    uint QUEUED = 5;
    uint EXPIRED = 6;
    uint EXECUTED = 7;

    env e0;
    env e1;
    require e1.block.number == e0.block.number + 1;
    require e1.block.timestamp > e0.block.timestamp;
    require e1.block.timestamp - e0.block.timestamp < sinvoke certoraTimelockGracePeriod(e0);
    require sinvoke certoraTimelockDelay(e0) > 0;

    // XXX cannot propose
    /* uint proposalId = sinvoke certoraPropose(e0); */
    /* require invoke certoraProposalLength(e0, proposalId) <= 5; */
    uint proposalId;
    uint nProposals = sinvoke proposalCount(e0);
    require proposalId < nProposals;

    // Ensure the executed flag is not (arbitrarily) set if eta has not been set yet
    require sinvoke certoraProposalEta(e0, proposalId) == 0 => !sinvoke certoraProposalExecuted(e0, proposalId);

    uint startBlock = sinvoke certoraProposalStart(e0, proposalId);
    uint endBlock = sinvoke certoraProposalEnd(e0, proposalId);
    uint stateNow = sinvoke certoraProposalState(e0, proposalId);
    require startBlock < endBlock; // i.e. votingPeriod > 0

    // Do something
    method fun1; calldataarg arg1;
    invoke fun1(e0, arg1);

    // Do something else
    // XXX takes days to run, but catches violations in queue-execute
    //  but also thinks timelock delay = 0 according to output report
    /* method fun2; calldataarg arg2; */
    /* invoke fun2(e0, arg2); */

    uint startBlockNext = sinvoke certoraProposalStart(e1, proposalId);
    uint endBlockNext = sinvoke certoraProposalEnd(e1, proposalId);
    uint stateNext = sinvoke certoraProposalState(e1, proposalId);

    assert startBlockNext == startBlock, "Start block may not change";
    assert endBlockNext == endBlock, "End block may not change";

    // Possibilities based on time

    assert (e0.block.number <= startBlock) => (
        stateNow == CANCELED ||
        stateNow == PENDING
     ), "Prior to voting, may only be pending or canceled";

    assert (e0.block.number > startBlock && e0.block.number <= endBlock) => (
        stateNow == CANCELED ||
        stateNow == ACTIVE
     ), "During voting, may only be active or canceled";

    assert (e0.block.number > endBlock) => (
        stateNow == CANCELED ||
        stateNow == DEFEATED ||
        stateNow == SUCCEEDED ||
        stateNow == QUEUED ||
        stateNow == EXPIRED ||
        stateNow == EXECUTED
     ), "After voting, must be in a viable state";

    /* // Allowed transitions */

    assert (stateNow == PENDING) => (
        (stateNext == CANCELED) ||
        (stateNext == ACTIVE && e1.block.number > startBlock) ||
        (stateNext == PENDING)
     ), "From pending, must either become canceled, active, or remain pending";

    assert (stateNow == ACTIVE) => (
        (stateNext == CANCELED) ||
        ((
         stateNext == DEFEATED ||
         stateNext == SUCCEEDED ||
         stateNext == QUEUED ||
         stateNext == EXPIRED ||
         stateNext == EXECUTED
        ) && e1.block.number > endBlock) ||
        (stateNext == ACTIVE)
     ), "From active, must either become canceled, a viable next statem or remain active";

    assert (stateNow == CANCELED) => (stateNext == CANCELED), "Once canceled, always canceled";

    assert (stateNow == DEFEATED) => (
        stateNext == CANCELED ||
        stateNext == DEFEATED
     ), "From defeated, must either become canceled, or remain defeated";

    assert (stateNow == SUCCEEDED) => (
        stateNext == CANCELED ||
        stateNext == QUEUED ||
        stateNext == SUCCEEDED
     ), "From succeeded, must either become canceled, queued, or remain succeeded";

    assert (stateNow == QUEUED) => (
        stateNext == CANCELED ||
        stateNext == EXPIRED ||
        stateNext == EXECUTED ||
        stateNext == QUEUED
     ), "From queued, must either become canceled, expired, executed, or remain queued";

    assert (stateNow == EXPIRED) => (
        stateNext == CANCELED ||
        stateNext == EXPIRED
     ), "From expired, must either become canceled, or remain expired";

    assert (stateNow == EXECUTED) => (stateNext == EXECUTED), "Once executed, always executed";
}

voteOnce(uint proposalId, bool support) {
    env e0;
    env e1;
    require e0.msg.sender == e1.msg.sender;

    uint nProposals = sinvoke proposalCount(e0);
    require proposalId < nProposals;

    invoke castVote(e0, proposalId, support);
    bool firstVoteReverted = lastReverted;

    invoke castVote(e1, proposalId, support);
    bool secondVoteReverted = lastReverted;

    assert !firstVoteReverted => secondVoteReverted, "Second vote succeeded after first";
}

votesSum(uint proposalId, bool support, address voterA, address voterB) {
    env e0;
    env e1;
    require e0.msg.sender == voterA;
    require e1.msg.sender == voterB;

    uint nProposals = sinvoke proposalCount(e0);
    require proposalId < nProposals;

    uint preVotesFor = sinvoke certoraProposalVotesFor(e0, proposalId);
    uint preVotesAgainst = sinvoke certoraProposalVotesAgainst(e0, proposalId);

    sinvoke castVote(e0, proposalId, support);
    sinvoke castVote(e1, proposalId, support);

    uint postVotesFor = sinvoke certoraProposalVotesFor(e1, proposalId);
    uint postVotesAgainst = sinvoke certoraProposalVotesAgainst(e1, proposalId);

    uint voterAVotes = sinvoke certoraVoterVotes(e1, proposalId, voterA);
    uint voterBVotes = sinvoke certoraVoterVotes(e1, proposalId, voterB);

    // XXX violates?
    assert postVotesFor >= preVotesFor, "Cannot reduce votes for";
    assert postVotesAgainst >= preVotesAgainst, "Cannot reduce votes against";
    assert postVotesFor - preVotesFor + postVotesAgainst - preVotesAgainst == voterAVotes + voterBVotes, "Delta votes equals voter votes";
}