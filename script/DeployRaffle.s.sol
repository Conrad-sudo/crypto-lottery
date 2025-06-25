//SPDX License-Identifier: MIT
pragma solidity 0.8.19;

import {Raffle} from "../src/Raffle.sol";
import {Test} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Test {
    Raffle raffle;

    function run() external {}

    function deployContract() public returns (Raffle, HelperConfig) {
        //Deploys the helper config contract
        HelperConfig helperConfig = new HelperConfig();
        // Get the configuration for the current network
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinatorV2_5) =
                createSubscription.createSubscription(config.vrfCoordinatorV2_5,config.account);
            //Do some stuff to create a subscription

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinatorV2_5, config.subscriptionId, config.link,config.account);
        }

        // deploy the Raffle cotract
        vm.startBroadcast(config.account);
        raffle = new Raffle(
            config.subscriptionId,
            config.gasLane,
            config.automationUpdateInterval,
            config.raffleEntranceFee,
            config.callbackGasLimit,
            config.vrfCoordinatorV2_5
        );
        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer();
        // Add the raffle contract as a consumer to the VRF subscription
        addConsumer.addConsumer(config.subscriptionId, config.vrfCoordinatorV2_5, address(raffle),config.account);
        console.log("Raffle contract deployed at:", address(raffle));

        return (raffle, helperConfig);
    }
}
