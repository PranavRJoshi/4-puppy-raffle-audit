### [M-#] Use of for loop inside the `PuppyRaffle::enterRaffle` fuction to check for duplicates, potential Denial of Service (DoS) can be caused if many addresses enter the raffle, also increases the gas cost for future entrants 

**Description:** 

The `PuppyRaffle::enterRaffle` function loops through the array of addresses `PuppyRaffle::players`, to check for the duplicate address. This also provides an advantage to early players who have entered the raffle than those who enters later. As the size of the `PuppyRaffle::players` array increases, it will require effectively more gas to just enter the raffle or the function could not be executed as the gas required will be more than the block gas limit.

```javascript
    // @audit DoS attack
->    for (uint256 i = 0; i < players.length - 1; i++) {
        for (uint256 j = i + 1; j < players.length; j++) {
            require(players[i] != players[j], "PuppyRaffle: Duplicate player");
        }
    }
```

**Impact:** 

As the number of entrants increases, it will be more gas expensive to execute the `PuppyRaffle::enterRaffle` function as it needs to check for duplicate address in the `PuppyRaffle::players` variable. This discourages new users from entering the raffle and might also cause a rush at the start of the raffle as it costs relatively less gas to execute the function.

An attacker might make the `PuppyRaffle::players` array so big, that calling the function `PuppyRaffle::enterRaffle` will no longer be feasible, guarenteeing themselves to win.

**Proof of Concept:**

If we have two sets of 1000 players entering the raffle, it will approximately cost:
- First 1000 players: ~417,422,152 gas
- Second 1000 players: ~1,600,813,180 gas

<details>
<summary>PoC</summary>
Place the following test into `PuppyRaffleTest.t.sol`

```javascript
// @audit-test PoC to show potential DoS attack
    function test_enter_raffle_for_dos () public {
        vm.txGasPrice(1); 

        uint256 gas_required_to_generate_addresses = gasleft();
        uint256 players_num = 1000;
        address[] memory players = new address[](players_num);
        for (uint256 i = 0; i < players_num; i++) {
            players[i] = address(uint160(i));
        }
        uint256 gas_cost_to_generate_addresses = gas_required_to_generate_addresses - gasleft();
        console.log("Gas required to spawn first %s addresses is: %s", players_num, gas_cost_to_generate_addresses);
        
        uint256 gas_start_first = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * 1000}(players);
        uint256 gas_cost_first = gas_start_first - gasleft();
        console.log("Gas required for first 1000 addresses to enter the raffle: %s", gas_cost_first);
        console.log("Effective Gas Price for first call is: %s", gas_cost_first * tx.gasprice);

        gas_required_to_generate_addresses = gasleft();
        address[] memory players_two = new address[](players_num);
        for (uint256 i = 0; i < players_num; i++) {
            players_two[i] = address(uint160(i+1000));
        }
        gas_cost_to_generate_addresses = gas_required_to_generate_addresses - gasleft();
        console.log("Gas required to spawn second %s addresses is: %s", players_num, gas_cost_to_generate_addresses);
        
        uint256 gas_start_second = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * 1000}(players_two);
        uint256 gas_cost_second = gas_start_second - gasleft();
        console.log("Gas required for second 1000 addresses to enter the raffle: %s", gas_cost_second);
        console.log("Effective Gas Price for second call is: %s", gas_cost_second * tx.gasprice);

        assert(gas_cost_first < gas_cost_second);
    }
```
</details>

**Recommended Mitigation:**

There are a few recommendations.

1. Consider allowing duplicates. Users can make new wallet addresses anyway, hence a duplicate check doesn't prevent the same person from entering multiple times, only the same wallet address.
2. Consider using a mapping to check for duplicates. This would allow constant time lookup of whether a user has already entered.

```diff
+    mapping(address => uint256) public addressToRaffleId;
+    uint256 public raffleId = 0;
    .
    .
    .
    function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
        for (uint256 i = 0; i < newPlayers.length; i++) {
            players.push(newPlayers[i]);
+            addressToRaffleId[newPlayers[i]] = raffleId;            
        }

-        // Check for duplicates
+       // Check for duplicates only from the new players
+       for (uint256 i = 0; i < newPlayers.length; i++) {
+          require(addressToRaffleId[newPlayers[i]] != raffleId, "PuppyRaffle: Duplicate player");
+       }    
-        for (uint256 i = 0; i < players.length; i++) {
-            for (uint256 j = i + 1; j < players.length; j++) {
-                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
-            }
-        }
        emit RaffleEnter(newPlayers);
    }
.
.
.
    function selectWinner() external {
+       raffleId = raffleId + 1;
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
```

Alternatively, you can also use [OpenZeppelin's `EnumerableSet` library](https://docs.openzeppelin.com/contracts/4.x/api/utils#EnumerableSet)