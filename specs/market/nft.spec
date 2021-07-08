methods {
    ownerOf(uint) returns address envfree
    tokenOfOwnerByIndex(address,uint) returns uint envfree
    getApproved(uint) returns address envfree
    isApprovedForAll(address,address) returns bool envfree
}


////////////////////////////////////////////////////////////////////////////
//                       Definitions                                      //
////////////////////////////////////////////////////////////////////////////

definition mapIndexToArrayIndex(uint mapIndex) returns uint = mapIndex - 1;
definition arrayIndexToMapIndex(uint arrayIndex) returns uint = arrayIndex + 1;
definition isListedKey(uint k, uint i) returns bool = 0 <= i && i < numTokens() && arrayIndexToToken(i) == k;
definition isListedHolderKey(address owner, uint k, uint i) returns bool = 0 <= i && i < holderToNumTokens(owner) && holderAndArrayIndexToToken(owner, i) == k;

////////////////////////////////////////////////////////////////////////////
//                       Ghosts                                           //
////////////////////////////////////////////////////////////////////////////

// ownership related by owner
ghost holderAndTokenToMapIndex(address,uint /* tokenId */) returns uint {
    init_state axiom forall address k. forall uint t. holderAndTokenToMapIndex(k,t) == 0;
}
ghost holderToNumTokens(address) returns uint {
    init_state axiom forall address k. holderToNumTokens(k) == 0;
    axiom forall address k. holderToNumTokens(k) < max_uint256;
}
ghost holderAndArrayIndexToToken(address,uint /* index */) returns uint {
    init_state axiom forall address k. forall uint i. holderAndArrayIndexToToken(k,i) == 0;
}

hook Sstore _holderTokens[KEY address k].(offset 0).(offset 0 /* the array */)[INDEX uint i] uint newToken (uint oldToken) STORAGE {
    require k <= max_uint160;
    havoc holderAndArrayIndexToToken assuming holderAndArrayIndexToToken@new(k,i) == newToken
        && (forall address k2. forall uint i2. holderAndArrayIndexToToken@new(k2,i2) != holderAndArrayIndexToToken@old(k2,i2) => k == k2 && i == i2);
}

hook Sload uint owner _holderTokens[KEY address k].(offset 0).(offset 0 /* the array */)[INDEX uint i] STORAGE {
    require holderAndArrayIndexToToken(k,i) == owner;
}

hook Sstore _holderTokens[KEY address k].(offset 0).(offset 0 /* the array */) uint newLen (uint oldLen) STORAGE {
    require k <= max_uint160;
    havoc holderToNumTokens assuming holderToNumTokens@new(k) == newLen
        && (forall address k2. holderToNumTokens@new(k2) != holderToNumTokens@old(k2) => k == k2);
}

hook Sload uint len _holderTokens[KEY address k].(offset 0).(offset 0 /* the array */) STORAGE {
    require holderToNumTokens(k) == len;
}

hook Sstore _holderTokens[KEY address k].(offset 0).(offset 32 /* the map */)[KEY uint token] uint newIndex (uint oldIndex) STORAGE {
    require k <= max_uint160;
    havoc holderAndTokenToMapIndex assuming holderAndTokenToMapIndex@new(k,token) == newIndex
        && (forall address k2. forall uint token2. holderAndTokenToMapIndex@new(k2,token2) != holderAndTokenToMapIndex@old(k2,token2) => k == k2 && token == token2);
}

hook Sload uint index _holderTokens[KEY address k].(offset 0).(offset 32 /* the map */)[KEY uint token] STORAGE {
    require holderAndTokenToMapIndex(k,token) == index;
}


// ownership related by token
ghost arrayIndexToToken(mathint) returns uint { // must protect accesses - should not access with a negative
    init_state axiom forall uint i. arrayIndexToToken(i) == 0;
}

ghost arrayIndexToOwner(uint) returns address {
    init_state axiom forall uint i. arrayIndexToOwner(i) == 0;
}

ghost tokenToOwner(uint) returns uint {
    init_state axiom forall address t. tokenToOwner(t) == 0;
}
ghost numTokens() returns uint {
    init_state axiom numTokens() == 0;
}
ghost tokenToMapIndex(uint) returns uint {
    init_state axiom forall uint t. tokenToMapIndex(t) == 0;
}

// update a key in the array
hook Sstore _tokenOwners.(offset 0 /* the array */)[INDEX uint arrayIndex].(offset 0 /* key */) uint newKey (uint oldKey) STORAGE {
    uint actualIndex = (arrayIndex)/2;
    havoc arrayIndexToToken assuming arrayIndexToToken@new(actualIndex) == newKey
        && (forall uint i2. arrayIndexToToken@new(i2) != arrayIndexToToken@old(i2) => actualIndex == i2);
    address owner = arrayIndexToOwner(actualIndex);
    havoc tokenToOwner assuming tokenToOwner@new(newKey) == owner
        && (forall uint t2. tokenToOwner@new(t2) != tokenToOwner@old(t2) => newKey == t2);
}

hook Sload uint key _tokenOwners.(offset 0 /* the array */)[INDEX uint arrayIndex].(offset 0 /* key */) STORAGE {
    uint actualIndex = (arrayIndex)/2;
    require arrayIndexToToken(actualIndex) == key;
}

// update a value in the array
hook Sstore _tokenOwners.(offset 0 /* the array */)[INDEX uint arrayIndex].(offset 32 /* value */) address newValue (address oldValue) STORAGE {
    uint actualIndex = (arrayIndex)/2;
    havoc arrayIndexToOwner assuming arrayIndexToOwner@new(actualIndex) == newValue
        && (forall uint i2. arrayIndexToOwner@new(i2) != arrayIndexToOwner@old(i2) => actualIndex == i2);
    address token = arrayIndexToToken(arrayIndex);
    havoc tokenToOwner assuming tokenToOwner@new(token) == newValue
        && (forall uint t2. tokenToOwner@new(t2) != tokenToOwner@old(t2) => token == t2);
}

hook Sload uint value _tokenOwners.(offset 0 /* the array */)[INDEX uint arrayIndex].(offset 32 /* value */) STORAGE {
    uint actualIndex = (arrayIndex)/2;
    require arrayIndexToOwner(actualIndex) == value;
}

hook Sstore _tokenOwners.(offset 0 /* the array */) uint newLen (uint oldLen) STORAGE {
    havoc numTokens assuming numTokens@new() == newLen;
}

hook Sload uint len _tokenOwners.(offset 0 /* the array */) STORAGE {
    require numTokens() == len;
}

hook Sstore _tokenOwners.(offset 32 /* the map */)[KEY uint t] uint newMapIndex (uint oldMapIndex) STORAGE {
    havoc tokenToMapIndex assuming tokenToMapIndex@new(t) == newMapIndex
        && (forall uint t2. tokenToMapIndex@new(t2) != tokenToMapIndex@old(t2) => t2 == t);
    // tokentoowner update?
}

hook Sload uint index _tokenOwners.(offset 32 /* the map */)[KEY uint t] STORAGE {
    require tokenToMapIndex(t) == index;
}

////////////////////////////////////////////////////////////////////////////
//                       Ghost check rules                                //
////////////////////////////////////////////////////////////////////////////

invariant holderTokenMapIndexLessThanOrEqNumTokens(address owner, uint t)
    (owner != 0 && t != 0) => holderAndTokenToMapIndex(owner, t) <= holderToNumTokens(owner) {
        preserved {
            requireInvariant holderTokenInListIffInMap(owner, t);
        }


        preserved burn(uint256 t2) with (env e) {
            require t2 != 0;
            validToken(t);
            validToken(t2);
            validOwnerToken(owner, t);
            validOwnerToken(owner, t2);
        }

        preserved transferFrom(address from, address to, uint t2) with (env e) {
            validToken(t2);
            validOwnerToken(from, t2);
            validOwnerToken(owner, t);
            validOwnerToken(owner, t2);
        }

        preserved safeTransferFrom(address from, address to, uint t2) with (env e) {
            validToken(t2);
            validOwnerToken(from, t2);
            validOwnerToken(owner, t);
            validOwnerToken(owner, t2);
        }
        /*
        preserved safeTransferFrom(address from, address to, uint t2, bytes x) with (env e) {
            validToken(t2);
            validOwnerToken(from, t2);
        }*/
    }

invariant holderTokenInListIffInMap(address owner, uint token) 
    (owner != 0 && token != 0) => ((holderAndTokenToMapIndex(owner, token) > 0 => holderAndArrayIndexToToken(owner, mapIndexToArrayIndex(holderAndTokenToMapIndex(owner, token))) == token)
    && (holderAndTokenToMapIndex(owner, token) == 0 => (forall uint j. !isListedHolderKey(owner, token, j))))

/*
rule sanity1(address owner, uint token) {
      require  (owner != 0 && token != 0);
    require  (owner != 0 && token != 0) => ((holderAndTokenToMapIndex(owner, token) > 0 => holderAndArrayIndexToToken(owner, mapIndexToArrayIndex(holderAndTokenToMapIndex(owner, token))) == token)
    && (holderAndTokenToMapIndex(owner, token) == 0 => (forall uint j. !isListedHolderKey(owner, token, j))));

    env e; calldataarg arg; method f; f(e,arg);

    assert  (owner != 0 && token != 0) => ((holderAndTokenToMapIndex(owner, token) > 0 => holderAndArrayIndexToToken(owner, mapIndexToArrayIndex(holderAndTokenToMapIndex(owner, token))) == token)
    && (holderAndTokenToMapIndex(owner, token) == 0 => (forall uint j. !isListedHolderKey(owner, token, j))));
   /// assert false;
}*/

invariant uniqueHolderTokensInList(address owner, uint t)
    (owner != 0 && t != 0) => (forall uint i. (forall uint j. ((isListedHolderKey(owner, t,i) && isListedHolderKey(owner, t, j)) => i == j))) {
        preserved {
            requireInvariant holderTokenMapIndexLessThanOrEqNumTokens(owner, t);
            requireInvariant holderTokenInListIffInMap(owner, t);
        }
    }

// status: passed
invariant tokenMapIndexLessThanOrEqNumTokens(uint t)
    t != 0 => tokenToMapIndex(t) <= numTokens() {
        preserved {
            requireInvariant tokenInMapAppearsInListAndViceVersa(t);
        }

        preserved burn(uint256 t2) with (env e) {
            require t2 != 0;
            requireInvariant tokenInMapAppearsInListAndViceVersa(t);
            requireInvariant tokenInMapAppearsInListAndViceVersa(t2);
        }
    }

// status: passed
invariant tokenInMapAppearsInListAndViceVersa(uint t)
    t != 0 => (tokenToMapIndex(t) > 0 => arrayIndexToToken(mapIndexToArrayIndex(tokenToMapIndex(t))) == t)
    && (tokenToMapIndex(t) == 0 => (forall uint j. !isListedKey(t,j))) 
    {
        preserved burn(uint256 t2) with (env e) {
            require t2 != 0;
            require numTokens() < max_uint256/2; // avoid overflows
            requireInvariant tokenMapIndexLessThanOrEqNumTokens(t);
            requireInvariant tokenMapIndexLessThanOrEqNumTokens(t2);
            requireInvariant tokenInMapAppearsInListAndViceVersa(t2);
            requireInvariant uniqueTokensInList(t);
            requireInvariant uniqueTokensInList(t2);
        }

        preserved {
            requireInvariant tokenMapIndexLessThanOrEqNumTokens(t);
            requireInvariant uniqueTokensInList(t);
            requireInvariant uniqueTokensInList(numTokens());
        }
    }

// status: passed
invariant uniqueTokensInList(uint t)
    t != 0 => (forall uint i. (forall uint j. ((isListedKey(t,i) && isListedKey(t,j)) => i == j))) {
        preserved {
            requireInvariant tokenMapIndexLessThanOrEqNumTokens(t);
            requireInvariant tokenInMapAppearsInListAndViceVersa(t);
        }
    }

////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////

// status: passed
rule noChangeToOther(uint tokenId, uint otherTokenId, method f) filtered { f -> !f.isFallback } {
    validToken(tokenId);
    validToken(otherTokenId);

    require tokenId != otherTokenId;

    address _tokenOwner = ownerOf(tokenId);
    address _otherTokenOwner = ownerOf(otherTokenId);

    env e;
    calldataarg arg;
    f(e,arg);

    address tokenOwner_ = ownerOf(tokenId);
    address otherTokenOwner_ = ownerOf(otherTokenId);

    assert _tokenOwner != tokenOwner_ => _otherTokenOwner == otherTokenOwner_;

}

// status: passed
rule tokenIndexMapsToTokensOwned(address owner, uint index, method f) filtered { f -> !f.isFallback } {
    uint tokenId = tokenOfOwnerByIndex(owner, index);
    validToken(tokenId);
    validOwnerToken(owner, tokenId);

    address _realOwner = ownerOf(tokenId);

    require _realOwner == owner;

    env e;
    bool canTransfer = isApprovedForAll(owner, e.msg.sender) || e.msg.sender == owner || getApproved(tokenId) == e.msg.sender;

    safeCall(f,e);

    uint tokenId_ = tokenOfOwnerByIndex(owner, index);

    if (tokenId_ == tokenId) {
        address realOwner_ = ownerOf(tokenId);
        assert realOwner_ == owner || canTransfer;
    }

    assert true;
}

////////////////////////////////////////////////////////////////////////////
//                       Functions                                        //
////////////////////////////////////////////////////////////////////////////
function validToken(uint t) {
    require t != 0;
    requireInvariant tokenMapIndexLessThanOrEqNumTokens(t);
    requireInvariant tokenInMapAppearsInListAndViceVersa(t);
    requireInvariant uniqueTokensInList(t);
}

function validOwnerToken(address o, uint t) {
    require o != 0;
    require t != 0;
    requireInvariant holderTokenMapIndexLessThanOrEqNumTokens(o,t);
    requireInvariant holderTokenInListIffInMap(o, t);
    requireInvariant uniqueHolderTokensInList(o, t);
}

function safeCall(method f, env e) {
    if (f.selector == burn(uint256).selector) {
        uint t;
        validToken(t);
        burn(e, t);
    } else if (f.selector == transferFrom(address,address,uint256).selector) {
        address from;
        address to;
        uint t;
        validToken(t);
        transferFrom(e,from,to,t);
        } else if (f.selector == safeTransferFrom(address,address,uint256).selector) {
        address from;
        address to;
        uint t;
        validToken(t);
        safeTransferFrom(e,from,to,t);
        } else if (f.selector == safeTransferFrom(address,address,uint256,bytes).selector) {
        address from;
        address to;
        uint t;
        validToken(t);
        safeTransferFrom(e,from,to,t); // omitting the bytes...
    } else {
        calldataarg arg;
        f(e, arg);
    }
}