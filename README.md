## About the contract

See original [Reddit post](https://www.reddit.com/r/ethtrader/comments/8sn7ir/predict_the_exact_day_eth_will_reach_1000_again/) for the origin story.

This contract allows participants to guess when they believe the price of ether (ETH) will next reach 1000 USD. Under the assumption that [u/Jimmyn3wbert](https://www.reddit.com/user/Jimmyn3wbert) will follow through with his promise and use this particular contract as the means of fulfilling it, the person whose guess is closest to when ETH hits the mark wins.

## Functionality

1. Participants include both a [UNIX timestamp](https://www.unixtimestamp.com/index.php) and the address that they want to receive the ETH in when making a guess. Only one guess per address is possible.

2. Once the `checkPrice` function is called, which can only be called by the contract owner, and assuming the price is greater than 1000 USD based on Kraken's last trade between the ETHUSD pairing on their API, `priceConfirmedOver1000` is set to true and the `payout` function can be called.

3. `payout` iterates through all the various participants and finds the one whose timestamp guess is closest to the winning timestamp, whether their guess falls before or after the winning timestamp. Note, there is nothing stopping the owner from putting a false timestamp in when he calls `payout`. Assuming good faith, he should call `checkPrice`, wait for Oraclize to return the `result` from the API call, then provide the timestamp returned in the event log (from when Oraclize was queried) in the `payout` function.

---

## Contributing to the project

This is an open source project. Contributions are welcomed & encouraged! :smile:

## TODO
* Audit and code review

## References
* [Oracalize](https://docs.oraclize.it/)
* [Kraken API](https://www.kraken.com/help/api#get-ticker-info)