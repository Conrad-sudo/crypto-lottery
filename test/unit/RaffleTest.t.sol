//SPDX License-Identifier: MIT
pragma solidity 0.8.19;

import {Raffle} from "../../src/Raffle.sol";
import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig,CodeConstants} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";


contract RaffleTest is Test,CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;
    address public player = makeAddr("player");

    uint256 public constant STARTING_PLAYER_BALACE = 10 ether;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 interval;
    uint256 enteranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinator;

    event RaffleEntered(address indexed player);


    modifier raffleEntered() {
        vm.prank(player);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + 2 * interval);
        vm.roll(block.number + 1);
       
        _;
    }

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        interval = config.automationUpdateInterval;
        enteranceFee = config.raffleEntranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinator = config.vrfCoordinatorV2_5;
        vm.deal(player, STARTING_PLAYER_BALACE);
    }

    function testRaffleIsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testEnternceFeeIsCorrect() public view {
        assertEq(raffle.getEnteranceFee(), enteranceFee);
    }

    function testPlayerCanEnterRaffle() public {
        vm.startPrank(player);
        raffle.enterRaffle{value: enteranceFee}();
        vm.stopPrank();

        assertEq(raffle.getNumberOfPlayers(), 1);
        assertEq(raffle.getPlayer(0), player);
    }

    function testSentAmount() public raffleEntered{
       
        assertEq(raffle.getBalance(), enteranceFee);
    }

    function testEnternceFeeIsNotCorrect() public {
        vm.startPrank(player);
        vm.expectRevert(Raffle.Raffle__notEnoughETHSent.selector);
        raffle.enterRaffle{value: enteranceFee - 1}();
        vm.stopPrank();
    }

    function testEnterRaffleEmitsEvent() public {
        vm.prank(player);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(player);
        raffle.enterRaffle{value: enteranceFee}();
    }

    function testPlayersCantEnterWhileCalculating() public  raffleEntered{
       
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__raffleNotOpen.selector);
        raffle.enterRaffle{value: enteranceFee}();
    }

    function testRecieveFunctionWorks() public {
        vm.prank(player);
        (bool success,) = address(raffle).call{value: enteranceFee}("");
        assert(success);
        assertEq(raffle.getNumberOfPlayers(), 1);
        assertEq(raffle.getPlayer(0), player);
        assertEq(raffle.getBalance(), enteranceFee);
    }

    

    /*
     //////////////////////////////////////////////
     //////////// CHECK UPKEEP/////////////////////
     //////////////////////////////////////////////
     */

    function testCheckUpKeepReturnsFalseIfNoBalance() public {
        vm.warp(block.timestamp + interval + 2);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsntOpen() public raffleEntered{
        
        raffle.performUpkeep("");
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimeHasPassed() public {
        vm.prank(player);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval - 10);
        vm.roll(block.number + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueIfConditionsAreMet() public raffleEntered{
        
        (bool upkeepNeeded,)=raffle.checkUpkeep("");
        assert(upkeepNeeded);
       
    }


    /*
     //////////////////////////////////////////////
     //////////// PERFORM UPKEEP/////////////////////
     //////////////////////////////////////////////
     */

    function testPerformUpKeepRevertsIfCheckUpkeepIsFalse() public {
        vm.warp(block.timestamp+interval+2);
        vm.roll(block.number + 1);
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, 0,0,raffle.getRaffleState()));
        raffle.performUpkeep("");
    }

    function testPerformUpKeepOnlyWorksIfCheckUpkeepIsTrue() public raffleEntered{
       
       
        raffle.performUpkeep("");
        assert(raffle.getRaffleState()==Raffle.RaffleState.CALCULATING);
    }

    function testPerformUpKeepEmitsRequestId() public raffleEntered{
        
       
        vm.recordLogs(); //record the logs of the following function call
        raffle.performUpkeep("");
        //get the logs recorded from performUkeep and stick them into this array
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId=entries[1].topics[1];

        assert(requestId != bytes32(0));
       
    }

    /*
     //////////////////////////////////////////////
     //////////// FULFILL RANDOM WORDS/////////////////////
     //////////////////////////////////////////////
     */

    modifier skipFork(){
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testfulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered  skipFork{

        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));

       
    }

    function testFulfilRandomWordsPicksAwinnerResetsAndSendsMoney() public raffleEntered skipFork{
        //Arrange
        uint256 additionalPlayers=3;
        uint256 startingIndex=1;
        address expectedWinner=address(1);
       

        for(uint256 i=startingIndex;i<additionalPlayers+startingIndex;i++){
            address newPlayer=address(uint160(i));
            hoax(newPlayer,1 ether);
            raffle.enterRaffle{value: enteranceFee}();

        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance=expectedWinner.balance;


        //Act
         vm.recordLogs(); //record the logs of the following function call
        raffle.performUpkeep("");
        //get the logs recorded from performUkeep and stick them into this array
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId=entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));


        //Assert

        address winner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance=winner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize= enteranceFee * (additionalPlayers + 1);


        assertEq(winner, expectedWinner);
        assert(uint256(raffleState)==0 );
        assertEq(winnerBalance, winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp); // Check that the timestamp has been updated

        

         // +1 for the initial player

    }




}
