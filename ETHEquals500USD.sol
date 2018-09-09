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

    constructor()  public {
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

contract ETHEquals500USD is usingOraclize, owned {

    using SafeMath for uint;
    using SafeMath for uint256;

    bool public priceConfirmedOver500 = false;
    bool public checkPriceCalled = false;
    bool public winnerPaid = false;
    uint public totalGuesses = 0;
    uint public totalNominees = 0;
    uint public winningTimestamp;
    uint public oraclePrice = 0;
    uint public lowestDiff = now; // initiate variable with arbitrarily high value
    address public winner; // seven day nomination period to establish winner
    uint internal CONTRACT_CREATED;
    uint constant internal SECS_IN_ONE_WEEK = 604800;
    uint constant internal SECS_IN_TWO_WEEKS = 1209600;
    mapping (address => uint) public participantId;
    Participant[] public participants;

    event EtherReceived(uint amount, address addr);
    event SomebodyGuessed(address guesser, uint timestamp, uint guesses);
    event NewNomination(address nominee, uint timestamp, uint diff);
    event Feedback(string message);
    event OraclizeResult(string message, uint result, uint timestamp);
    event WinnerAnnounced(string message, address winner, uint diff);

    struct Participant {
        address participant;
        uint participantSince; // when user made guess
        uint guess; // UNIX timestamp of user's guess
        bool hasGuessed; // ensure user can't change guess as price approaches closer to 500
        uint diff; // diff between winning time and guessed time, assigned once ETH hits 500 USD
    }

    constructor() public payable {
        CONTRACT_CREATED = block.timestamp;
        makeGuess(1230940800); //see below
    }

    // participants make guess by providing UNIX timestamp when they believe ETH >= 500 USD, as determined by Kraken API
    function makeGuess(uint timestamp) public {
        require(now < CONTRACT_CREATED + SECS_IN_TWO_WEEKS && !priceConfirmedOver500); // establishes guessing period of 14 days following contract creation, no guessing if price hits 500 USD within this timeframe
        uint id = participantId[msg.sender];

        if (id == 0) {
            participantId[msg.sender] = participants.length;
            id = participants.length++;
        }

        // instantiate first guess with null address (which can't win) and timestamp of 20090103 (homage to bitcoin genesis)
        // contract owner needs to use a different address in order to participate
        if (msg.sender == owner){
            participants[id] = Participant({participant: 0, participantSince: now, guess: timestamp, hasGuessed: true, diff: now});
        } else {
            // prevent user from changing guess, something that would happen if price approaches 500 during the guessing period
            if (participants[id].hasGuessed != true){
                participants[id] = Participant({participant: msg.sender, participantSince: now, guess: timestamp, hasGuessed: true, diff: now});
                totalGuesses++;
                emit SomebodyGuessed(msg.sender, timestamp, totalGuesses);
            }
        }
    }

    function() public payable {
        emit EtherReceived(msg.value, msg.sender);
    }

    // Oracalize callback - https://docs.oraclize.it
    function __callback(bytes32 myid, string result) {
        if (msg.sender != oraclize_cbAddress()) throw;
        uint _result = parseInt(result);
        emit OraclizeResult("Price checked", _result, now);
        if (_result >= 500){ // if greater than or equal to 500USD of last trade on Kraken API
            priceConfirmedOver500 = true;
            winningTimestamp = block.timestamp;
        }
    }

    // Query Kraken API to check ETHUSD price, will trigger __callback method from Oracalize
    function checkPrice() public payable {
        require(!priceConfirmedOver500 && msg.value >= oraclePrice); //ensure method can't be called again once oracle confirms we've crossed 500, thereby changing winningTimestamp. Ensure function caller pays Oracle callback fee
        if (oraclize_getPrice("URL") > address(this).balance) {
            emit Feedback("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            oraclize_query("URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
            oraclePrice = oraclize_getPrice("URL");
        }
    }

    function claimCheckPriceReward() public {
        require(!checkPriceCalled && priceConfirmedOver500); // reward first person to call this function with 10% of the balance AFTER checkPrice() is successfully called
        uint tenPercentBalance = address(this).balance.div(10);
        msg.sender.transfer(tenPercentBalance);
        checkPriceCalled = true;
    }

    function nominateSelfAsWinner(address possibleWinner) public {
        require(priceConfirmedOver500 && possibleWinner != 0); // can only be called once oracle has established we are over 500
        uint id = participantId[possibleWinner];
        Participant storage p = participants[id];
        require(p.participant == possibleWinner); // ensure nominee is actually a participant already

        // get nominees' diffs whether they guessed before or after `winningTimestamp`
        if (winningTimestamp > p.guess){
            p.diff = winningTimestamp.sub(p.guess);
        } else {
            p.diff = p.guess.sub(winningTimestamp);
        }

        // establish which of the nominees has the lowest diff and mark them as the winner until
        // replaced by someone with a better guess. Note, this contract is not set up for multiple
        // winners in the unlikely chance two or more addresses have the correct answer. In this
        // case, the person who nominated themselves second (i.e., after the other nominee with the
        // same winning guess called this function and established themselves in the lead) would win.

        if (p.diff <= lowestDiff) {
            lowestDiff = p.diff;
            winner = p.participant;
        }

        totalNominees++;
        emit NewNomination(possibleWinner, p.guess, p.diff);
    }

    function payout() public {
        require(now > winningTimestamp + SECS_IN_ONE_WEEK && !winnerPaid && winner != 0); // establishes nomination period of 1 week following price hitting 500

        // payout contract balance to `winner`
        if (winner.send(address(this).balance)) {
            emit WinnerAnnounced("Congrats!", winner, lowestDiff);
            winnerPaid = true;
        }
    }

    // send all ETH to nonprofit Give Directly in the event of some logic error or API problem
    function endContract() onlyOwner public {
        selfdestruct(0xc7464dbcA260A8faF033460622B23467Df5AEA42);
    }

}