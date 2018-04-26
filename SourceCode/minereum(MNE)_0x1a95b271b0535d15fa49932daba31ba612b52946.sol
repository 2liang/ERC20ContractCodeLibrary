contract minereum { 

string public name; 
string public symbol; 
uint8 public decimals; 
uint256 public initialSupplyPerAddress;
uint256 public initialBlockCount;
uint256 public rewardPerBlockPerAddress;
uint256 public totalGenesisAddresses;
address public genesisCallerAddress;
uint256 private availableAmount;
uint256 private availableBalance;
uint256 private minedBlocks;
uint256 private totalMaxAvailableAmount;
uint256 private balanceOfAddress;

mapping (address =&gt; uint256) public balanceOf; 
mapping (address =&gt; bool) public genesisAddress; 

event Transfer(address indexed from, address indexed to, uint256 value); 

function minereum() { 

name = &quot;minereum&quot;; 
symbol = &quot;MNE&quot;; 
decimals = 8; 
initialSupplyPerAddress = 3200000000000;
initialBlockCount = 3516521;
rewardPerBlockPerAddress = 32000;
totalGenesisAddresses = 4268;

genesisCallerAddress = 0x0000000000000000000000000000000000000000;
}

function currentEthBlock() constant returns (uint256 blockNumber)
{
	return block.number;
}

function currentBlock() constant returns (uint256 blockNumber)
{
	return block.number - initialBlockCount;
}

function setGenesisAddressArray(address[] _address) public returns (bool success)
{
	if (block.number &lt;= 3597381)
	{
		if (msg.sender == genesisCallerAddress)
		{
			for (uint i = 0; i &lt; _address.length; i++)
			{
				balanceOf[_address[i]] = initialSupplyPerAddress;
				genesisAddress[_address[i]] = true;
			}
			return true;
		}
	}
	return false;
}


function availableBalanceOf(address _address) constant returns (uint256 Balance)
{
	if (genesisAddress[_address])
	{
		minedBlocks = block.number - initialBlockCount;
		
		if (minedBlocks &gt;= 100000000) return balanceOf[_address];
		
		availableAmount = rewardPerBlockPerAddress*minedBlocks;
		
		totalMaxAvailableAmount = initialSupplyPerAddress - availableAmount;
		
		availableBalance = balanceOf[_address] - totalMaxAvailableAmount;
		
		return availableBalance;
	}
	else
		return balanceOf[_address];
}

function totalSupply() constant returns (uint256 totalSupply)
{	
	minedBlocks = block.number - initialBlockCount;
	availableAmount = rewardPerBlockPerAddress*minedBlocks;
	return availableAmount*totalGenesisAddresses;
}

function maxTotalSupply() constant returns (uint256 maxSupply)
{	
	return initialSupplyPerAddress*totalGenesisAddresses;
}

function transfer(address _to, uint256 _value) { 

if (genesisAddress[_to]) throw;

if (balanceOf[msg.sender] &lt; _value) throw; 

if (balanceOf[_to] + _value &lt; balanceOf[_to]) throw; 

if (genesisAddress[msg.sender])
{
	minedBlocks = block.number - initialBlockCount;
	if (minedBlocks &lt; 100000000)
	{
		availableAmount = rewardPerBlockPerAddress*minedBlocks;
			
		totalMaxAvailableAmount = initialSupplyPerAddress - availableAmount;
		
		availableBalance = balanceOf[msg.sender] - totalMaxAvailableAmount;
			
		if (_value &gt; availableBalance) throw;
	}
}

balanceOf[msg.sender] -= _value; 
balanceOf[_to] += _value; 
Transfer(msg.sender, _to, _value); 
} 

function setGenesisCallerAddress(address _caller) public returns (bool success)
{
	if (genesisCallerAddress != 0x0000000000000000000000000000000000000000) return false;
	
	genesisCallerAddress = _caller;
	
	return true;
}
}