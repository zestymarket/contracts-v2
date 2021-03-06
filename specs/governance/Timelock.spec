rule queueTransaction(address target, uint256 value, uint256 eta) {
    env e0;

    address admin_ = sinvoke admin(e0);
    uint256 delay_ = sinvoke delay(e0);

    bytes32 txHash = invoke queueTransactionStatic(e0, target, value, eta);
    bool queueReverted = lastReverted;
    bool queued = sinvoke queuedTransactions(e0, txHash);

    assert (!queueReverted => queued), "Did not revert but not queued";
    assert ((eta < (e0.block.timestamp + delay_)) => queueReverted), "ETA too soon but did not revert";
    assert (!queueReverted => (queued <=> ((eta >= e0.block.timestamp + delay_) && admin_ == e0.msg.sender))), "Bad queue";
}

rule cancelTransaction(address target, uint256 value, uint256 eta) {
    env e0;
    env e1;
    env e2;

    bytes32 txHash = sinvoke queueTransactionStatic(e0, target, value, eta);
    bool queuedPre = sinvoke queuedTransactions(e0, txHash);
    assert queuedPre, "Queue did not revert, but not queued";

    sinvoke cancelTransactionStatic(e1, target, value, eta);
    bool queuedPost = sinvoke queuedTransactions(e1, txHash);
    assert !queuedPost, "Cancel did not revert, but queued";

    invoke executeTransactionStatic(e1, target, value, eta);
    bool executeReverted = lastReverted;
    assert executeReverted, "Transaction was canceled, must not be able to execute";
}

rule executeTransaction(address target, uint256 value, uint256 eta) {
    env e0;
    env e1;

    uint256 deltaT = e1.block.timestamp - e0.block.timestamp;
    require deltaT >= 0; // Certora does not infer this from block number

    address admin_ = sinvoke admin(e0);
    uint256 delay_ = sinvoke delay(e0);
    uint256 grace_ = sinvoke grace(e0);

    bytes32 txHash = sinvoke queueTransactionStatic(e0, target, value, eta);
    bool queuedPre = sinvoke queuedTransactions(e0, txHash);
    assert queuedPre, "Queue did not revert, but not queued";

    invoke executeTransactionStatic(e1, target, value, eta);
    bool executeReverted = lastReverted;
    bool queuedPost = sinvoke queuedTransactions(e1, txHash);

    assert (!executeReverted => !queuedPost), "Did not revert, should no longer be queued";
    assert (!executeReverted => deltaT >= delay_), "Did not revert, must not execute before Timelock minimum delay";
    assert (!executeReverted =>
            (deltaT >= eta - e0.block.timestamp &&
             deltaT <= eta - e0.block.timestamp + grace_)),
        "Did not revert, should only execute within grace period of eta";
    assert ((e1.msg.sender != admin_) => executeReverted), "Must revert if not admin";
}

rule cannotExecuteTransaction(address target, uint256 value, uint256 eta) {
    env e0;
    env e1;

    bytes32 txHash = sinvoke queueTransactionStatic(e0, target, value, eta);
    bool queuedPre = sinvoke queuedTransactions(e0, txHash);
    assert queuedPre, "Queue did not revert, but not queued";

    address target_;
    require target_ != target;

    uint256 value_;
    require value_ != value;

    uint256 eta_;
    require eta_ != eta;

    invoke executeTransactionStatic(e1, target_, value, eta);
    assert lastReverted, "Executed tx with different target";

    invoke executeTransactionStatic(e1, target, value_, eta);
    assert lastReverted, "Executed tx with different value";

    invoke executeTransactionStatic(e1, target, value, eta_);
    assert lastReverted, "Executed tx with different eta";

    bool queuedPost = sinvoke queuedTransactions(e1, txHash);
    assert queuedPost, "Dequeued the transaction, but not canceled or executed";
}