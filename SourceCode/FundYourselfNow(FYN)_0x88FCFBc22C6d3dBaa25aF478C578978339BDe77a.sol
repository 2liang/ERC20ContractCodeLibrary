pragma solidity ^0.4.11;
/*
This FYN token contract is derived from the vSlice ICO contract, based on the ERC20 token contract. 
Additional functionality has been integrated:
* the function mintTokens() only callable from wallet, which makes use of the currentSwapRate() and safeToAdd() helpers
* the function mintReserve() only callable from wallet, which at the end of the crowdsale will allow the owners to claim the unsold tokens
* the function stopToken() only callable from wallet, which in an emergency, will trigger a complete and irrecoverable shutdown of the token
* Contract tokens are locked when created, and no tokens including pre-mine can be moved until the crowdsale is over.
*/


// ERC20 Token Standard Interface
// https://github.com/ethereum/EIPs/issues/20
contract ERC20 {
    function totalSupply() constant returns (uint);
    function balanceOf(address who) constant returns (uint);
    function allowance(address owner, address spender) constant returns (uint);

    function transfer(address to, uint value) returns (bool ok);
    function transferFrom(address from, address to, uint value) returns (bool ok);
    function approve(address spender, uint value) returns (bool ok);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

contract Token is ERC20 {

  string public constant name = &quot;FundYourselfNow Token&quot;;
  string public constant symbol = &quot;FYN&quot;;
  uint8 public constant decimals = 18;  // 18 is the most common number of decimal places
  uint256 public tokenCap = 12500000e18; // 12.5 million FYN cap 

  address public walletAddress;
  uint256 public creationTime;
  bool public transferStop;
 
  mapping( address =&gt; uint ) _balances;
  mapping( address =&gt; mapping( address =&gt; uint ) ) _approvals;
  uint _supply;

  event TokenMint(address newTokenHolder, uint amountOfTokens);
  event TokenSwapOver();
  event EmergencyStopActivated();

  modifier onlyFromWallet {
      if (msg.sender != walletAddress) throw;
      _;
  }

  // Check if transfer should stop
  modifier checkTransferStop {
      if (transferStop == true) throw;
      _;
  }
 

  /**
   *
   * Fix for the ERC20 short address attack
   *
   * http://vessenes.com/the-erc20-short-address-attack-explained/
   */

  modifier onlyPayloadSize(uint size) {
     if (!(msg.data.length == size + 4)) throw;
     _;
   } 
 
  function Token( uint initial_balance, address wallet, uint256 crowdsaleTime) {
    _balances[msg.sender] = initial_balance;
    _supply = initial_balance;
    walletAddress = wallet;
    creationTime = crowdsaleTime;
    transferStop = true;
  }

  function totalSupply() constant returns (uint supply) {
    return _supply;
  }

  function balanceOf( address who ) constant returns (uint value) {
    return _balances[who];
  }

  function allowance(address owner, address spender) constant returns (uint _allowance) {
    return _approvals[owner][spender];
  }

  // A helper to notify if overflow occurs
  function safeToAdd(uint a, uint b) private constant returns (bool) {
    return (a + b &gt;= a &amp;&amp; a + b &gt;= b);
  }
  
  // A helper to notify if overflow occurs for multiplication
  function safeToMultiply(uint _a, uint _b) private constant returns (bool) {
    return (_b == 0 || ((_a * _b) / _b) == _a);
  }

  // A helper to notify if underflow occurs for subtraction
  function safeToSub(uint a, uint b) private constant returns (bool) {
    return (a &gt;= b);
  }


  function transfer( address to, uint value)
    checkTransferStop
    onlyPayloadSize(2 * 32)
    returns (bool ok) {

    if (to == walletAddress) throw; // Reject transfers to wallet (wallet cannot interact with token contract)
    if( _balances[msg.sender] &lt; value ) {
        throw;
    }
    if( !safeToAdd(_balances[to], value) ) {
        throw;
    }

    _balances[msg.sender] -= value;
    _balances[to] += value;
    Transfer( msg.sender, to, value );
    return true;
  }

  function transferFrom( address from, address to, uint value)
    checkTransferStop
    returns (bool ok) {

    if (to == walletAddress) throw; // Reject transfers to wallet (wallet cannot interact with token contract)

    // if you don&#39;t have enough balance, throw
    if( _balances[from] &lt; value ) {
        throw;
    }
    // if you don&#39;t have approval, throw
    if( _approvals[from][msg.sender] &lt; value ) {
        throw;
    }
    if( !safeToAdd(_balances[to], value) ) {
        throw;
    }
    // transfer and return true
    _approvals[from][msg.sender] -= value;
    _balances[from] -= value;
    _balances[to] += value;
    Transfer( from, to, value );
    return true;
  }

  function approve(address spender, uint value)
    checkTransferStop
    returns (bool ok) {

    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(_spender,0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    //
    // Note that this doesn&#39;t prevent attacks; the user will have to personally
    //  check to ensure that the token count has not changed, before issuing
    //  a new approval. Increment/decrement is not commonly spec-ed, and 
    //  changing to a check-my-approvals-before-changing would require user
    //  to find out his current approval for spender and change expected
    //  behaviour for ERC20.


    if ((value!=0) &amp;&amp; (_approvals[msg.sender][spender] !=0)) throw;

    _approvals[msg.sender][spender] = value;
    Approval( msg.sender, spender, value );
    return true;
  }

  // The function currentSwapRate() returns the current exchange rate
  // between FYN tokens and Ether during the token swap period
  function currentSwapRate() constant returns(uint) {
      uint presalePeriod = 3 days;
      uint presaleTransitionWindow = 3 hours;
      if (creationTime + presalePeriod &gt; now) {  // 2017-06-10 11am GMT+8
          return 140; // Presale Window is triggered by both time and &quot;Start Token Swap / End Token Swap&quot;. Restricted to announement range and basic testing.
      } 
      else if (creationTime + presalePeriod + 3 weeks &gt; now) { // 2017-06-13 11am GMT+8, but we will only Start Token Swap at 2pm
          return 120;
      }
      else if (creationTime + presalePeriod + 6 weeks + 6 days + 3 hours + presaleTransitionWindow + 1 days &gt; now) { // 2017-07-31 5pm GMT+8 (+1 day window  )
          // 1 day buffer to allow one final transaction from anyone to close everything
          // otherwise wallet will receive ether but send 0 tokens
          // we cannot throw as we will lose the state change to start swappability of tokens 
          // This is actually just a price guide, actual closing is done at the Wallet level
          return 100;
      }
      else {
          return 0;
      }
  }

  // The function mintTokens is only usable by the chosen wallet
  // contract to mint a number of tokens proportional to the
  // amount of ether sent to the wallet contract. The function
  // can only be called during the tokenswap period
  function mintTokens(address newTokenHolder, uint etherAmount)
    external
    onlyFromWallet {
        if (!safeToMultiply(currentSwapRate(), etherAmount)) throw;
        uint tokensAmount = currentSwapRate() * etherAmount;

        if(!safeToAdd(_balances[newTokenHolder],tokensAmount )) throw;
        if(!safeToAdd(_supply,tokensAmount)) throw;

        if ((_supply + tokensAmount) &gt; tokenCap) throw;

        _balances[newTokenHolder] += tokensAmount;
        _supply += tokensAmount;

        TokenMint(newTokenHolder, tokensAmount);
  }

  function mintReserve(address beneficiary) 
    external
    onlyFromWallet {
        if (tokenCap &lt;= _supply) throw;
        if(!safeToSub(tokenCap,_supply)) throw;
        uint tokensAmount = tokenCap - _supply;

        if(!safeToAdd(_balances[beneficiary], tokensAmount )) throw;
        if(!safeToAdd(_supply,tokensAmount)) throw;

        _balances[beneficiary] += tokensAmount;
        _supply += tokensAmount;
        
        TokenMint(beneficiary, tokensAmount);
  }

  // The function disableTokenSwapLock() is called by the wallet
  // contract once the token swap has reached its end conditions
  function disableTokenSwapLock()
    external
    onlyFromWallet {
        transferStop = false;
        TokenSwapOver();
  }

  // Once activated, a new token contract will need to be created, mirroring the current token holdings. 
  function stopToken() onlyFromWallet {
    transferStop = true;
    EmergencyStopActivated();
  }
}


/*
The standard Wallet contract, retrievable at
https://github.com/ethereum/dapp-bin/blob/master/wallet/wallet.sol has been
modified to include additional functionality, in particular:
* An additional parent of wallet contract called tokenswap, implementing almost
all the changes:
    - Functions for starting and stopping the tokenswap
    - A set-only-once function for the token contract
    - buyTokens(), which calls mintTokens() in the token contract
    - Modifiers for enforcing tokenswap time limits, max ether cap, and max token cap
    - withdrawEther(), for withdrawing unsold tokens after time cap
* the wallet fallback function calls the buyTokens function
* the wallet contract cannot selfdestruct during the tokenswap
*/

contract multiowned {

	// TYPES

    // struct for the status of a pending operation.
    struct PendingState {
        uint yetNeeded;
        uint ownersDone;
        uint index;
    }

	// EVENTS

    // this contract only has six types of events: it can accept a confirmation, in which case
    // we record owner and operation (hash) alongside it.
    event Confirmation(address owner, bytes32 operation);
    event Revoke(address owner, bytes32 operation);
    // some others are in the case of an owner changing.
    event OwnerChanged(address oldOwner, address newOwner);
    event OwnerAdded(address newOwner);
    event OwnerRemoved(address oldOwner);
    // the last one is emitted if the required signatures change
    event RequirementChanged(uint newRequirement);

	// MODIFIERS

    // simple single-sig function modifier.
    modifier onlyowner {
        if (isOwner(msg.sender))
            _;
    }
    // multi-sig function modifier: the operation must have an intrinsic hash in order
    // that later attempts can be realised as the same underlying operation and
    // thus count as confirmations.
    modifier onlymanyowners(bytes32 _operation) {
        if (confirmAndCheck(_operation))
            _;
    }

	// METHODS

    // constructor is given number of sigs required to do protected &quot;onlymanyowners&quot; transactions
    // as well as the selection of addresses capable of confirming them.
    function multiowned(address[] _owners, uint _required) {
        m_numOwners = _owners.length + 1;
        m_owners[1] = uint(msg.sender);
        m_ownerIndex[uint(msg.sender)] = 1;
        for (uint i = 0; i &lt; _owners.length; ++i)
        {
            m_owners[2 + i] = uint(_owners[i]);
            m_ownerIndex[uint(_owners[i])] = 2 + i;
        }
        m_required = _required;
    }

    // Revokes a prior confirmation of the given operation
    function revoke(bytes32 _operation) external {
        uint ownerIndex = m_ownerIndex[uint(msg.sender)];
        // make sure they&#39;re an owner
        if (ownerIndex == 0) return;
        uint ownerIndexBit = 2**ownerIndex;
        var pending = m_pending[_operation];
        if (pending.ownersDone &amp; ownerIndexBit &gt; 0) {
            pending.yetNeeded++;
            pending.ownersDone -= ownerIndexBit;
            Revoke(msg.sender, _operation);
        }
    }

    // Replaces an owner `_from` with another `_to`.
    function changeOwner(address _from, address _to) onlymanyowners(sha3(msg.data)) external {
        if (isOwner(_to)) return;
        uint ownerIndex = m_ownerIndex[uint(_from)];
        if (ownerIndex == 0) return;

        clearPending();
        m_owners[ownerIndex] = uint(_to);
        m_ownerIndex[uint(_from)] = 0;
        m_ownerIndex[uint(_to)] = ownerIndex;
        OwnerChanged(_from, _to);
    }

    function addOwner(address _owner) onlymanyowners(sha3(msg.data)) external {
        if (isOwner(_owner)) return;

        clearPending();
        if (m_numOwners &gt;= c_maxOwners)
            reorganizeOwners();
        if (m_numOwners &gt;= c_maxOwners)
            return;
        m_numOwners++;
        m_owners[m_numOwners] = uint(_owner);
        m_ownerIndex[uint(_owner)] = m_numOwners;
        OwnerAdded(_owner);
    }

    function removeOwner(address _owner) onlymanyowners(sha3(msg.data)) external {
        uint ownerIndex = m_ownerIndex[uint(_owner)];
        if (ownerIndex == 0) return;
        if (m_required &gt; m_numOwners - 1) return;

        m_owners[ownerIndex] = 0;
        m_ownerIndex[uint(_owner)] = 0;
        clearPending();
        reorganizeOwners(); //make sure m_numOwner is equal to the number of owners and always points to the optimal free slot
        OwnerRemoved(_owner);
    }

    function changeRequirement(uint _newRequired) onlymanyowners(sha3(msg.data)) external {
        if (_newRequired &gt; m_numOwners) return;
        m_required = _newRequired;
        clearPending();
        RequirementChanged(_newRequired);
    }

    // Gets an owner by 0-indexed position (using numOwners as the count)
    function getOwner(uint ownerIndex) external constant returns (address) {
        return address(m_owners[ownerIndex + 1]);
    }

    function isOwner(address _addr) returns (bool) {
        return m_ownerIndex[uint(_addr)] &gt; 0;
    }

    function hasConfirmed(bytes32 _operation, address _owner) constant returns (bool) {
        var pending = m_pending[_operation];
        uint ownerIndex = m_ownerIndex[uint(_owner)];

        // make sure they&#39;re an owner
        if (ownerIndex == 0) return false;

        // determine the bit to set for this owner.
        uint ownerIndexBit = 2**ownerIndex;
        return !(pending.ownersDone &amp; ownerIndexBit == 0);
    }

    // INTERNAL METHODS

    function confirmAndCheck(bytes32 _operation) internal returns (bool) {
        // determine what index the present sender is:
        uint ownerIndex = m_ownerIndex[uint(msg.sender)];
        // make sure they&#39;re an owner
        if (ownerIndex == 0) return;

        var pending = m_pending[_operation];
        // if we&#39;re not yet working on this operation, switch over and reset the confirmation status.
        if (pending.yetNeeded == 0) {
            // reset count of confirmations needed.
            pending.yetNeeded = m_required;
            // reset which owners have confirmed (none) - set our bitmap to 0.
            pending.ownersDone = 0;
            pending.index = m_pendingIndex.length++;
            m_pendingIndex[pending.index] = _operation;
        }
        // determine the bit to set for this owner.
        uint ownerIndexBit = 2**ownerIndex;
        // make sure we (the message sender) haven&#39;t confirmed this operation previously.
        if (pending.ownersDone &amp; ownerIndexBit == 0) {
            Confirmation(msg.sender, _operation);
            // ok - check if count is enough to go ahead.
            if (pending.yetNeeded &lt;= 1) {
                // enough confirmations: reset and run interior.
                delete m_pendingIndex[m_pending[_operation].index];
                delete m_pending[_operation];
                return true;
            }
            else
            {
                // not enough: record that this owner in particular confirmed.
                pending.yetNeeded--;
                pending.ownersDone |= ownerIndexBit;
            }
        }
    }

    function reorganizeOwners() private {
        uint free = 1;
        while (free &lt; m_numOwners)
        {
            while (free &lt; m_numOwners &amp;&amp; m_owners[free] != 0) free++;
            while (m_numOwners &gt; 1 &amp;&amp; m_owners[m_numOwners] == 0) m_numOwners--;
            if (free &lt; m_numOwners &amp;&amp; m_owners[m_numOwners] != 0 &amp;&amp; m_owners[free] == 0)
            {
                m_owners[free] = m_owners[m_numOwners];
                m_ownerIndex[m_owners[free]] = free;
                m_owners[m_numOwners] = 0;
            }
        }
    }

    function clearPending() internal {
        uint length = m_pendingIndex.length;
        for (uint i = 0; i &lt; length; ++i)
            if (m_pendingIndex[i] != 0)
                delete m_pending[m_pendingIndex[i]];
        delete m_pendingIndex;
    }

   	// FIELDS

    // the number of owners that must confirm the same operation before it is run.
    uint public m_required;
    // pointer used to find a free slot in m_owners
    uint public m_numOwners;

    // list of owners
    uint[256] m_owners;
    uint constant c_maxOwners = 250;
    // index on the list of owners to allow reverse lookup
    mapping(uint =&gt; uint) m_ownerIndex;
    // the ongoing operations.
    mapping(bytes32 =&gt; PendingState) m_pending;
    bytes32[] m_pendingIndex;
}

// inheritable &quot;property&quot; contract that enables methods to be protected by placing a linear limit (specifiable)
// on a particular resource per calendar day. is multiowned to allow the limit to be altered. resource that method
// uses is specified in the modifier.
contract daylimit is multiowned {

	// MODIFIERS

    // simple modifier for daily limit.
    modifier limitedDaily(uint _value) {
        if (underLimit(_value))
            _;
    }

	// METHODS

    // constructor - stores initial daily limit and records the present day&#39;s index.
    function daylimit(uint _limit) {
        m_dailyLimit = _limit;
        m_lastDay = today();
    }
    // (re)sets the daily limit. needs many of the owners to confirm. doesn&#39;t alter the amount already spent today.
    function setDailyLimit(uint _newLimit) onlymanyowners(sha3(msg.data)) external {
        m_dailyLimit = _newLimit;
    }
    // resets the amount already spent today. needs many of the owners to confirm.
    function resetSpentToday() onlymanyowners(sha3(msg.data)) external {
        m_spentToday = 0;
    }

    // INTERNAL METHODS

    // checks to see if there is at least `_value` left from the daily limit today. if there is, subtracts it and
    // returns true. otherwise just returns false.
    function underLimit(uint _value) internal onlyowner returns (bool) {
        // reset the spend limit if we&#39;re on a different day to last time.
        if (today() &gt; m_lastDay) {
            m_spentToday = 0;
            m_lastDay = today();
        }
        // check if it&#39;s sending nothing (with or without data). This needs Multitransact
        if (_value == 0) return false;

        // check to see if there&#39;s enough left - if so, subtract and return true.
        // overflow protection                    // dailyLimit check
        if (m_spentToday + _value &gt;= m_spentToday &amp;&amp; m_spentToday + _value &lt;= m_dailyLimit) {
            m_spentToday += _value;
            return true;
        }
        return false;
    }
    // determines today&#39;s index.
    function today() private constant returns (uint) { return now / 1 days; }

	// FIELDS

    uint public m_dailyLimit;
    uint public m_spentToday;
    uint public m_lastDay;
}

// interface contract for multisig proxy contracts; see below for docs.
contract multisig {

	// EVENTS

    // logged events:
    // Funds has arrived into the wallet (record how much).
    event Deposit(address _from, uint value);
    // Single transaction going out of the wallet (record who signed for it, how much, and to whom it&#39;s going).
    event SingleTransact(address owner, uint value, address to, bytes data);
    // Multi-sig transaction going out of the wallet (record who signed for it last, the operation hash, how much, and to whom it&#39;s going).
    event MultiTransact(address owner, bytes32 operation, uint value, address to, bytes data);
    // Confirmation still needed for a transaction.
    event ConfirmationNeeded(bytes32 operation, address initiator, uint value, address to, bytes data);

    // FUNCTIONS

    // TODO: document
    function changeOwner(address _from, address _to) external;
    function execute(address _to, uint _value, bytes _data) external returns (bytes32);
    function confirm(bytes32 _h) returns (bool);
}

contract tokenswap is multisig, multiowned {
    Token public tokenCtr;
    bool public tokenSwap;
    uint public constant PRESALE_LENGTH = 3 days;
    uint public constant TRANSITION_WINDOW = 3 hours; // We will turn on tokenSwap in this period and it will 120 FYN / ETH
    uint public constant SWAP_LENGTH = PRESALE_LENGTH + TRANSITION_WINDOW + 6 weeks + 6 days + 3 hours;
    uint public constant MAX_ETH = 75000 ether; // Hard cap, capped otherwise by total tokens sold (max 7.5M FYN)
    uint public amountRaised;

    modifier isUnderPresaleMinimum {
        if (tokenCtr.creationTime() + PRESALE_LENGTH &gt; now) {
            if (msg.value &lt; 20 ether) throw;
        }
        _;
    }

    modifier isZeroValue {
        if (msg.value == 0) throw;
        _;
    }

    modifier isOverCap {
    	if (amountRaised + msg.value &gt; MAX_ETH) throw;
        _;
    }

    modifier isOverTokenCap {
        if (!safeToMultiply(tokenCtr.currentSwapRate(), msg.value)) throw;
        uint tokensAmount = tokenCtr.currentSwapRate() * msg.value;
        if(!safeToAdd(tokenCtr.totalSupply(),tokensAmount)) throw;
        if (tokenCtr.totalSupply() + tokensAmount &gt; tokenCtr.tokenCap()) throw;
        _;

    }

    modifier isSwapStopped {
        if (!tokenSwap) throw;
        _;
    }

    modifier areConditionsSatisfied {
        _;
        // End token swap if sale period ended
        // We can&#39;t throw to reverse the amount sent in or we will lose state
        // , so we will accept it even though if it is after crowdsale
        if (tokenCtr.creationTime() + SWAP_LENGTH &lt; now) {
            tokenCtr.disableTokenSwapLock();
            tokenSwap = false;
        }
        // Check if cap has been reached in this tx
        if (amountRaised == MAX_ETH) {
            tokenCtr.disableTokenSwapLock();
            tokenSwap = false;
        }

        // Check if token cap has been reach in this tx
        if (tokenCtr.totalSupply() == tokenCtr.tokenCap()) {
            tokenCtr.disableTokenSwapLock();
            tokenSwap = false;
        }
    }

    // A helper to notify if overflow occurs for addition
    function safeToAdd(uint a, uint b) private constant returns (bool) {
      return (a + b &gt;= a &amp;&amp; a + b &gt;= b);
    }
  
    // A helper to notify if overflow occurs for multiplication
    function safeToMultiply(uint _a, uint _b) private constant returns (bool) {
      return (_b == 0 || ((_a * _b) / _b) == _a);
    }


    function startTokenSwap() onlyowner {
        tokenSwap = true;
    }

    function stopTokenSwap() onlyowner {
        tokenSwap = false;
    }

    function setTokenContract(address newTokenContractAddr) onlyowner {
        if (newTokenContractAddr == address(0x0)) throw;
        // Allow setting only once
        if (tokenCtr != address(0x0)) throw;

        tokenCtr = Token(newTokenContractAddr);
    }

    function buyTokens(address _beneficiary)
    payable
    isUnderPresaleMinimum
    isZeroValue
    isOverCap
    isOverTokenCap
    isSwapStopped
    areConditionsSatisfied {
        Deposit(msg.sender, msg.value);
        tokenCtr.mintTokens(_beneficiary, msg.value);
        if (!safeToAdd(amountRaised, msg.value)) throw;
        amountRaised += msg.value;
    }

    function withdrawReserve(address _beneficiary) onlyowner {
	    if (tokenCtr.creationTime() + SWAP_LENGTH &lt; now) {
            tokenCtr.mintReserve(_beneficiary);
        }
    } 
}

// usage:
// bytes32 h = Wallet(w).from(oneOwner).transact(to, value, data);
// Wallet(w).from(anotherOwner).confirm(h);
contract Wallet is multisig, multiowned, daylimit, tokenswap {

	// TYPES

    // Transaction structure to remember details of transaction lest it need be saved for a later call.
    struct Transaction {
        address to;
        uint value;
        bytes data;
    }

    // METHODS

    // constructor - just pass on the owner array to the multiowned and
    // the limit to daylimit
    function Wallet(address[] _owners, uint _required, uint _daylimit)
            multiowned(_owners, _required) daylimit(_daylimit) {
    }

    // kills the contract sending everything to `_to`.
    function kill(address _to) onlymanyowners(sha3(msg.data)) external {
        // ensure owners can&#39;t prematurely stop token sale
        if (tokenSwap) throw;
        // ensure owners can&#39;t kill wallet without stopping token
        //  otherwise token can never be stopped
        if (tokenCtr.transferStop() == false) throw;
        suicide(_to);
    }

    // Activates Emergency Stop for Token
    function stopToken() onlymanyowners(sha3(msg.data)) external {
       tokenCtr.stopToken();
    }

    // gets called when no other function matches
    function()
    payable {
        buyTokens(msg.sender);
    }

    // Outside-visible transact entry point. Executes transaction immediately if below daily spend limit.
    // If not, goes into multisig process. We provide a hash on return to allow the sender to provide
    // shortcuts for the other confirmations (allowing them to avoid replicating the _to, _value
    // and _data arguments). They still get the option of using them if they want, anyways.
    function execute(address _to, uint _value, bytes _data) external onlyowner returns (bytes32 _r) {
        // Disallow the wallet contract from calling token contract once it&#39;s set
        // so tokens can&#39;t be minted arbitrarily once the sale starts.
        // Tokens can be minted for premine before the sale opens and tokenCtr is set.
        if (_to == address(tokenCtr)) throw;

        // first, take the opportunity to check that we&#39;re under the daily limit.
        if (underLimit(_value)) {
            SingleTransact(msg.sender, _value, _to, _data);
            // yes - just execute the call.
            if(!_to.call.value(_value)(_data))
            return 0;
        }

        // determine our operation hash.
        _r = sha3(msg.data, block.number);
        if (!confirm(_r) &amp;&amp; m_txs[_r].to == 0) {
            m_txs[_r].to = _to;
            m_txs[_r].value = _value;
            m_txs[_r].data = _data;
            ConfirmationNeeded(_r, msg.sender, _value, _to, _data);
        }
    }

    // confirm a transaction through just the hash. we use the previous transactions map, m_txs, in order
    // to determine the body of the transaction from the hash provided.
    function confirm(bytes32 _h) onlymanyowners(_h) returns (bool) {
        if (m_txs[_h].to != 0) {
            if (!m_txs[_h].to.call.value(m_txs[_h].value)(m_txs[_h].data))   // Bugfix: If successful, MultiTransact event should fire; if unsuccessful, we should throw
                throw;
            MultiTransact(msg.sender, _h, m_txs[_h].value, m_txs[_h].to, m_txs[_h].data);
            delete m_txs[_h];
            return true;
        }
    }

    // INTERNAL METHODS

    function clearPending() internal {
        uint length = m_pendingIndex.length;
        for (uint i = 0; i &lt; length; ++i)
            delete m_txs[m_pendingIndex[i]];
        super.clearPending();
    }

	// FIELDS

    // pending transactions we have at present.
    mapping (bytes32 =&gt; Transaction) m_txs;
}