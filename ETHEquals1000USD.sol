pragma solidity ^0.4.11;
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract owned {
    address public owner;

    function owned()  public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner  public {
        owner = newOwner;
    }
}

contract ETHEquals1000USD is usingOraclize, owned {

    using SafeMath for uint;
    using SafeMath for uint256;

    bool public priceConfirmedOver1000 = false;
    bool public checkPriceCalled = false;
    uint public totalGuesses = 0;
    uint public totalAmount = 0;
    uint public winningTimestamp;
    uint internal CONTRACT_CREATED = block.timestamp;
    uint internal SECS_IN_ONE_WEEK = 604800;
    uint internal SECS_IN_30_DAYS = 2592000;
    mapping (address => uint) public participantId;
    Participant[] public participants;
    Nominee[] public nominees;

    event EtherReceived(uint amount, uint total);
    event SomebodyGuessed(address guesser, uint timestamp, uint guesses);
    event NewNomination(address nominee, uint timestamp, uint diff);
    event OraclizeResult(string message, string result, uint timestamp);
    event WinnerAnnounced(string message, address winner, uint diff, uint amount);

    struct Participant {
        address participant;
        uint participantSince; // when user made guess
        uint guess; // UNIX timestamp of user's guess
        bool hasGuessed; // ensure user can't change guess as price approaches closer to 1000
        uint diff; // diff between winning time and guessed time, assigned once ETH hits 1000 USD
    }

    struct Nominee {
        address nominee;
        uint diff;
    }

    function ETHEquals1000USD() {
        makeGuess(0, now); //instantiate first guess with null values to avoid errors, see Ethereum DAO example contract
    }

    // participants make guess by providing UNIX timestamp when they believe ETH >= 1000 USD, as determined by Kraken API
    function makeGuess(address targetParticipant, uint timestamp) public {
        require(CONTRACT_CREATED + SECS_IN_30_DAYS > now); // establishes guessing period of 30 days following contract creation
        uint id = participantId[targetParticipant];

        // runs on contract creation only
        if (id == 0) {
            participantId[targetParticipant] = participants.length;
            id = participants.length++;
        }

        // prevent user from changing guess, something that may happen a lot as price approaches 1000
        if (participants[id].hasGuessed != true){
            participants[id] = Participant({participant: targetParticipant, participantSince: now, guess: timestamp, hasGuessed: true, diff: now});
            totalGuesses++;
            SomebodyGuessed(targetParticipant, timestamp, totalGuesses);
        }
    }

    function() payable public {
        totalAmount = totalAmount.add(msg.value);
        EtherReceived(msg.value, totalAmount);
    }

    // Oracalize callback - https://docs.oraclize.it
    function __callback(bytes32 myid, string result) {
        if (msg.sender != oraclize_cbAddress()) throw;
        uint _result = stringToUint(result); //convert Oracalize result to uint
        OraclizeResult("Price checked", result, now);
        if (_result >= 100000000){ // this number is 1000USD, but `result` loses decimal after string/uint conversion and Kraken API has 5 trailing zeros in return value of price
            priceConfirmedOver1000 = true;
            winningTimestamp = block.timestamp;
        }
    }

    function stringToUint(string s) constant returns (uint) {
        bytes memory b = bytes(s);
        uint result = 0;
        for (uint i = 0; i < b.length; i++) { // c = b[i] was not needed
            if (b[i] >= 48 && b[i] <= 57) {
                result = result * 10 + (uint(b[i]) - 48); // bytes and int are not compatible with the operator -.
            }
        }
        return result;
    }

    // Query Kraken API to check ETHUSD price, will trigger __callback method from Oracalize
    function checkPrice() public {
        require(!priceConfirmedOver1000); //ensure method can't be called again once oracle confirms we've crossed 1000, thereby changing winningTimestamp.
        oraclize_query("URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
    }

    function claimCheckPriceReward() {
        require(!checkPriceCalled && priceConfirmedOver1000); // reward first person to call this function with 10% of totalAmount AFTER checkPrice() is successfully called
        uint tenPercentBalance = totalAmount.div(10);
        msg.sender.transfer(tenPercentBalance);
        totalAmount = totalAmount.sub(tenPercentBalance);
        checkPriceCalled = true;
    }

    function nominateSelfAsWinner(address possibleWinner) public {
        require(priceConfirmedOver1000); // can only be called once oracle has established we are over 1000
        uint id = participantId[possibleWinner];
        Participant storage p = participants[id];
        require(p.hasGuessed); // ensure nominee is actually a participant already

        if (winningTimestamp > p.guess){
            p.diff = winningTimestamp.sub(p.guess);
        } else {
            p.diff = p.guess.sub(winningTimestamp);
        }
        nominees.push(Nominee({nominee: possibleWinner, diff: p.diff}));
        NewNomination(possibleWinner, p.guess, p.diff);
    }

    function payout() payable public {
        require(winningTimestamp + SECS_IN_ONE_WEEK > now); // establishes nomination period of 1 week following price hitting 1000
        uint lowestDiff = 1529757632; // initiate variable with arbitrarily high timestamp, corresponds to 20180623 date
        address winner;

        //determine which nominee has the lowest diff and is thus the winner
        for(uint i = 0; i < nominees.length; i++){
            if (nominees[i].diff < lowestDiff){
                lowestDiff = nominees[i].diff;
                winner = nominees[i].nominee;
            }
        }

        winner.transfer(totalAmount);
        WinnerAnnounced("Congrats!", winner, lowestDiff, totalAmount);
    }

    // allows contract owner to reclaim ETH in the event of some logic error
    function endContract() onlyOwner public {
        selfdestruct(owner);
    }

}