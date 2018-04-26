pragma solidity ^0.4.16;

contract LatiumX {
    string public constant name = &quot;LatiumX&quot;;
    string public constant symbol = &quot;LATX&quot;;
    uint8 public constant decimals = 8;
    uint256 public constant totalSupply =
        300000000 * 10 ** uint256(decimals);

    // owner of this contract
    address public owner;

    // balances for each account
    mapping (address =&gt; uint256) public balanceOf;

    // triggered when tokens are transferred
    event Transfer(address indexed _from, address indexed _to, uint _value);

    // constructor
    function LatiumX() {
        owner = msg.sender;
        balanceOf[owner] = totalSupply;
    }

    // transfer the balance from sender&#39;s account to another one
    function transfer(address _to, uint256 _value) {
        // prevent transfer to 0x0 address
        require(_to != 0x0);
        // sender and recipient should be different
        require(msg.sender != _to);
        // check if the sender has enough coins
        require(_value &gt; 0 &amp;&amp; balanceOf[msg.sender] &gt;= _value);
        // check for overflows
        require(balanceOf[_to] + _value &gt; balanceOf[_to]);
        // subtract coins from sender&#39;s account
        balanceOf[msg.sender] -= _value;
        // add coins to recipient&#39;s account
        balanceOf[_to] += _value;
        // notify listeners about this transfer
        Transfer(msg.sender, _to, _value);
    }
}