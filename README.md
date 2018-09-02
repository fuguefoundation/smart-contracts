## About the contract

See Reddit posts [here](https://www.reddit.com/r/ethtrader/comments/8ta4l4/eth_at_1000_usd_smart_contract/) and [here](https://www.reddit.com/r/ethtrader/comments/8tgjqk/update_eth_at_1000usd_smart_contract/) for development and discussion about this experiment.

This contract allows participants to guess when they believe the price of ether (ETH) will next reach 500 USD. The contract is loaded with 0.5 ETH (though anyone can add more), and there are two possibilities to receive these funds.

1. **10% of balance**: The participant to first call `claimCheckPriceReward()` once the oracle has set `priceConfirmedOver500` to true.
2. **90% of balance**: The participant whose timestamp guess is closest to when ETH hits the 500 USD mark according to the Kraken API.

## Functionality and Contract Logic

1. When making a guess, participants include a [UNIX timestamp](https://www.unixtimestamp.com/index.php). `msg.sender` is the address that is making the guess and would receive the ETH.

* Guessing period is open for 14 days following contract creation.
* One guess per address, and participant can't change their guess once made. This is done to prevent people from changing their guess if price starts approaching 500USD during the 14 day guessing period.

2. When `checkPrice` is called, and assuming the price is greater than 500 USD based on Kraken's last trade between the ETHUSD pairing on their API, the oracle callback function sets `priceConfirmedOver500` to true and `winningTimestamp` is set to the current block timestamp.

* `winningTimestamp` is determined by the blockchain and not the instant price breaks 500 on Kraken. Thus, all functions (except `selfdestruct`) can be called by anyone.
* As an incentive mechanism to call `checkPrice` as close as possible to when we actually pass 500USD, the first person to call `claimCheckPriceReward` **AFTER** `priceConfirmedOver500` is set to true by the oracle is rewarded 10% of the contract's current `totalAmount`. To be clear, the person who gets the reward is not the person who called `checkPrice` but the person who called `claimCheckPriceReward` after `priceConfirmedOver500` is set to true by the oracle. The reason for this is because there are possible gas errors by having the oracle `__callback` call other functions that are `payable`.

3. Now the nomination period begins and lasts for seven days. Instead of iterating over the myriad guesses that may exist, creating possible gas issues, people who think they have a chance of winning nominate themselves, creating a smaller subset of possible winners who effectively compete for the lowest difference between their guess and `winningTimestamp`.

* The nomination period lasts for seven days following when `winningTimestamp` is established by the oracle. `payout` can be called by anyone following this seven day period, and the address who got closest to `winningTimestamp` takes all that remains in `totalAmount`. It doesn't matter if you guessed over or below `winningTimestamp`, it's all about who is closest.
* Note, the contract does not account for the unlikely scenario where two or more addresses nominate themselves with the same `lowestDiff` relative to `winningTimestamp`. I experimented a little with a few ways of checking for/implementing this and just let it be. In this unique situation, the contract logic is such that the last address nominated during the nomination period would be set as `winner`.

4. Self Destruct - I have included an escape hatch that the `owner` can call in the event that there is some unforeseen logic error or if Kraken's API changes. The address hard-coded in the contract is for the nonprofit Give Directly ([proof](https://givedirectly.org/give-now?crypto=eth)), who would receive the contract balance if this function is called.

## How to deploy

* [Remix](https://remix.ethereum.org) with Metamask. Copy the contract into a new file, compile with  Solidity 0.4.24, then go under the Run tab paste in the contract address where it says `at Address`. This should allow you to interact with the various functions
* [MyEtherWallet](https://www.myetherwallet.com/#contracts): Copy the abi.json file in this repo and paste in the contract address
* There are several other ways, to include Mist and the Geth command line

## Test contracts

* [Rinkeby test](https://rinkeby.etherscan.io/address/0x701efc16e34b0f95ea2f9399b0da699d3f391af3)
* [Another Rinkeby test](https://rinkeby.etherscan.io/address/0xd19634ba56f6e59a41de04889e211b22c75ae9f6)
* There are many others self-destructed on Rinkeby

These contracts evolved during the testing period, and differed (in terms of the variables) only by setting the threshold lower for ETHUSD price (relative to current market price) and eliminating the amount of time to elapse to call certain functions.

---

## Contributing to the project

This is an open source project. Contributions are welcomed & encouraged! :smile:

## TODO
* Allow for multiple winners
* Think of something more complex for ETH1000 contract

## References
* [Oracalize](https://docs.oraclize.it/)
* [Kraken API](https://www.kraken.com/help/api#get-ticker-info)
* [UNIX Timestamp converter](https://www.unixtimestamp.com/index.php)
* Compiled with Solidity 0.4.24