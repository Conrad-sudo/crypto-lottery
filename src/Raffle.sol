//SPDX License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle Contract
 * @author Conrad Japhet
 * @notice This contract is a simple raffle contract that allows users to enter a raffle by sending ether.
 * @dev Implements Chainlink VRF v2.5 for random number generation.
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors*/
    error Raffle__raffleNotOpen();
    error Raffle__transactionFailed();
    error Raffle__notOwner();
    error Raffle__notEnoughETHSent();
    error Raffle__UpkeepNotNeeded(uint256 playerLength, uint256 balance, uint256 raffleState);
    //Type Declarations

    enum RaffleState {
        OPEN,
        CALCULATING
    }
    /* State Variables */

    address payable immutable i_owner;
    uint256 private immutable i_enteranceFee;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;

    RaffleState public s_raffleState;
    // @dev The time interval for the raffle to be drawn in seconds
    uint256 immutable i_interval;
    // Sepolia coordinator. For other networks,
    // see https://docs.chain.link/vrf/v2-5/supported-networks#configurations
    address public vrfCoordinator;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/vrf/v2-5/supported-networks#configurations
    bytes32 public s_keyHash;
    // The default is 3, but you can set this higher.
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    uint256 s_subscriptionId;

    /* Events */
    /// @notice Emitted when a player enters the raffle
    event RaffleEntered(address indexed player);

    event WinnerPicked(address indexed winner, uint256 indexed requestID);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 _subscriptionId,
        bytes32 gasLane,
        uint256 interval,
        uint256 enteranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinator
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_owner = payable(msg.sender);
        i_enteranceFee = enteranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        s_keyHash = gasLane;
        s_subscriptionId = _subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    receive() external payable {
        enterRaffle();
    }

    fallback() external payable {
        enterRaffle();
    }

    function enterRaffle() public payable {
        //require(msg.value == i_enteranceFee, "Incorrect amount of ether sent");
        if (msg.value != i_enteranceFee) revert Raffle__notEnoughETHSent();
        if (s_raffleState != RaffleState.OPEN) revert Raffle__raffleNotOpen();
        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    /*    * @notice Checks if the upkeep is needed
    *
    * @return performData - empty bytes, unused in this contract
    * @dev Chainlink Keeper compatible function to check if upkeep is needed
    * Followıng creteria must be met:
    * 1. The raffle must be open
    * 2. The time interval must have passed since the last winner was picked
    * 3. There must be at least one player in the raffle
    * 4. The contract must have a balance greater than 0
    * @return upkeepNeeded - true if upkeep is needed, false otherwise
    */
    function checkUpkeep(bytes memory) public view returns (bool upkeepNeeded, bytes memory) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isLotteryOpen = s_raffleState == RaffleState.OPEN;
        bool contractHasETH = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isLotteryOpen && hasPlayers && contractHasETH;
        return (upkeepNeeded, "0x0");
    }

    //1. Get a random number
    //2. Use random number to pick a player
    //3. Be automatically called
    function performUpkeep(bytes calldata /* performData */ ) public {
        (bool upKeepNeeded,) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpkeepNotNeeded(s_players.length, address(this).balance, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;

       uint256 requestId= s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        emit RequestedRaffleWinner(requestId);

        //Request RNG
        //Get RNG
    }

    //CEI Checks effects ,interactions
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        //Effects
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0); // Reset the players array for the next raffle
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(recentWinner, requestId);

        //Interactions
        (bool success,) = recentWinner.call{value: address(this).balance}("");

        if (!success) {
            revert Raffle__transactionFailed();
        }
    }

    function getEnteranceFee() public view returns (uint256) {
        return i_enteranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }
}
