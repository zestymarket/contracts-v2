
// Verify that wards behaves correctly on rely
rule rely(address usr) {
    env e;

    uint256 ward = wards(e.msg.sender);

    rely@withrevert(e, usr);

    if (!lastReverted) {
        assert(wards(usr) == 1, "Rely did not set the wards as expected");
    }

    assert(ward == 0 => lastReverted, "Lack of auth did not revert");
    assert(e.msg.value > 0 => lastReverted, "Sending ETH did not revert");
}