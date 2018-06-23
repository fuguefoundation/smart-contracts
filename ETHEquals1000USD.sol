pragma solidity ^0.4.11;
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

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

    uint public totalGuesses = 0;
    bool public priceConfirmedOver1000 = false;
    uint public totalAmount = 0;
    mapping (address => uint) public participantId;
    Participant[] public participants;

    event EtherReceived(uint amount, uint total);
    event SomebodyGuessed(address guesser, uint timestamp, uint guesses);
    event OraclizeResult(string message, uint result, uint timestamp);
    event WinnerAnnounced(string message, address winner, uint amount);

    struct Participant {
        address participant;
        uint participantSince; // when user made guess
        uint guess; // UNIX timestamp of user's guess
        uint diff; // diff between winning time and guessed time, assigned once ETH hits 1000 USD
    }

    function ETHEquals1000USD() {
        //instantiate first guess with null values to avoid errors
        makeGuess(0, now);
    }

    // participants make guess by providing UNIX timestamp when they believe ETH >= 1000 USD, as determined by Kraken API
    function makeGuess(address targetParticipant, uint timestamp) public {
        uint id = participantId[targetParticipant];
        if (id == 0) {
            participantId[targetParticipant] = participants.length;
            id = participants.length++;
        }
        participants[id] = Participant({participant: targetParticipant, participantSince: now, guess: timestamp, diff: 0});
        totalGuesses++;
        SomebodyGuessed(msg.sender, timestamp, totalGuesses);
    }

    function() payable public {
        totalAmount += msg.value;
        EtherReceived(msg.value, totalAmount);
    }

    // Oracalize callback - https://docs.oraclize.it
    function __callback(bytes32 myid, string _result) {
        if (msg.sender != oraclize_cbAddress()) throw;
        uint result = parseInt(_result);
        OraclizeResult("Price checked", result, now);
        if (result >= 1000) {
            priceConfirmedOver1000 = true;
        }
    }

    // Query Kraken API to check ETHUSD price, will trigger __callback method from Oracalize
    function checkPrice() onlyOwner {
        oraclize_query("URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
    }

    function payout(uint winningTimestamp) onlyOwner payable {
        require(priceConfirmedOver1000);

        // set diff between participant's guess and winningTimestamp
        for(uint i = 0; i < participants.length; i++){
            Participant storage p = participants[i];
            // get difference between guess and winning time, whether guess falls before or after winning time
            if (winningTimestamp > p.guess){
                p.diff = winningTimestamp - p.guess;
            } else {
                p.diff = p.guess - winningTimestamp;
            }
        }

        uint lowestDiff = 1529757632; // initiate variable with a recent timestamp

        //iterate over the diffs to establish what the lowest diff is
        for(uint j = 0; j < participants.length; j++){
            Participant storage p2 = participants[j];
            if (p2.diff < lowestDiff){
                lowestDiff = p2.diff;
            }
        }

        address winner;

        //determine which participant has the lowest diff and is thus the winner
        for(uint k = 0; k < participants.length; k++){
            Participant storage p3 = participants[k];
            if (p3.diff == lowestDiff){
                winner = p3.participant;
            }
        }

        winner.transfer(totalAmount);
        WinnerAnnounced("Congrats!", winner, totalAmount);
    }

    function endContract() onlyOwner public {
        selfdestruct(owner);
    }

}
