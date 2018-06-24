## About the contract

See original [Reddit post](https://www.reddit.com/r/ethtrader/comments/8sn7ir/predict_the_exact_day_eth_will_reach_1000_again/) for the origin story. Development threads from ETHTrader community [here](https://www.reddit.com/r/ethtrader/comments/8ta4l4/eth_at_1000_usd_smart_contract/) and [here]().

This contract allows participants to guess when they believe the price of ether (ETH) will next reach 1000 USD. Under the assumption that [u/Jimmyn3wbert](https://www.reddit.com/user/Jimmyn3wbert) will follow through with his promise and use this particular contract as the means of fulfilling it, the person whose guess is closest to when ETH hits the mark wins.

## Test contract

This contract deployed to `Rinkeby`, [this contract](https://rinkeby.etherscan.io/address/0xd19634ba56f6e59a41de04889e211b22c75ae9f6) is identical to the solidity code here except the threshold for ETHUSD price is set to 475USD and `checkPrice` can only be called by owner because only the first call to Oracalize is free (i.e., we can't make another call to oracle since we are using test ether).

## Functionality

1. Participants include both a [UNIX timestamp](https://www.unixtimestamp.com/index.php) and an address that will receive the ETH when making a guess.

* Guessing period is open for one month following contract creation.
* One guess per address, and participant can't change their guess once made. This is done to prevent people from changing their guess either once their time has passed or as we approach closer to 1000USD.

2. When `checkPrice` is called, and assuming the price is greater than 1000 USD based on Kraken's last trade between the ETHUSD pairing on their API, the oracle callback function sets `priceConfirmedOver1000` to true and `winningTimestamp` is set to the current block timestamp.

* To be clear, `winningTimestamp` is determined by the blockchain and not the instant price breaks 1000 on Kraken. Thus, all functions (except `selfdestruct`) can be called by anyone.
* As an incentive mechanism to call `checkPrice` as close as possible to when we actually pass 1000USD, the first person to call `claimCheckPriceReward` **AFTER** `priceConfirmedOver1000` is set to true by the oracle is rewarded 10% of the contract's `totalAmount`. To be clear, the person who gets the reward is not the person who called `checkPrice` but the person who called `claimCheckPriceReward` after `checkPrice` is called successfully. The reason for this is because there are possible gas errors by having the oracle callback call other functions that are `payable`.

3. Now the nomination period begins. Instead of iterating over the myriad guesses that may exist, creating possible gas issues, people who think they have a chance of winning nominate themselves, creating a smaller subset of possible winners.

* The nomination period lasts for seven days following when `winningTimestamp` is established by the oracle. `payout` can be called by anyone following this seven day period, and the address who got closest to the winning timestamp takes all that remains in `totalAmount`
* Anyone can add more ETH to the total pot, though bear in mind that the bigger it gets the more incentivized the contract owner is to call `selfdestruct` and take it all for himself

---

## Contributing to the project

This is an open source project. Contributions are welcomed & encouraged! :smile:

## TODO
* Audit and code review
* Testing on Rinkeby

## References
* [Oracalize](https://docs.oraclize.it/)
* [Kraken API](https://www.kraken.com/help/api#get-ticker-info)
* [UNIX Timestamp converter](https://www.unixtimestamp.com/index.php)