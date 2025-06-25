# 🎟️ Raffle Smart Contract

## Overview

The **Raffle** smart contract is a decentralized lottery system that allows participants to enter by paying a fixed ETH fee. At set intervals, a random winner is selected using **Chainlink VRF v2.5**, ensuring provably fair randomness.

This contract is designed to run autonomously using Chainlink Keepers (Automation) to determine when to draw a winner.

---

## Features

- 🧾 **Fixed Entry Fee** — Participants must send a specified amount of ETH to enter.
- 🎰 **Provable Randomness** — Winner is chosen using Chainlink VRF (Verifiable Random Function) v2.5.
- ⏱️ **Time-Based Draws** — Uses a configurable time interval between raffles.
- 🔁 **Self-Running** — Chainlink Automation calls the `performUpkeep` function when it's time to draw a winner.
- 🛡️ **Security Checks** — Validates conditions before performing sensitive operations.

---

## 🧩 Cloning & Installing with Foundry

### ✅ Step Install Foundry (if not already installed)

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

---

### ✅ Clone the Project

```bash
git clone https://github.com/Conrad-sudo/crypto-lottery.git
cd crypto-lottery
```

---

### ✅ Install Dependencies

Refer to the `Makefile` for dependencies

Run:

```bash
make install
```

If this project uses Chainlink and other external dependencies via Git submodules or GitHub packages, they'll be fetched now.

> ⚠️ If the `lib` directory or `foundry.toml` is missing, run `forge init` before this step, or check that it's included in the repo.

---

## How It Works

1. **Enter Raffle**

   - Send ETH equal to the entrance fee to the contract.
   - The sender’s address is added to the player pool.
   - Raffle must be in the `OPEN` state.

2. **Check Upkeep**

   - Conditions checked:

     - Raffle is `OPEN`
     - At least one participant
     - Time interval has passed
     - Contract has balance

3. **Perform Upkeep**

   - Triggered manually or via Chainlink Automation.
   - Requests a random number from Chainlink VRF.

4. **Fulfill Random Words**

   - Chainlink returns a random number.
   - A winner is selected from the pool.
   - All funds are transferred to the winner.
   - State is reset for the next round.

---

## Deployment Parameters

Constructor Parameters:

| Parameter          | Description                                               |
| ------------------ | --------------------------------------------------------- |
| `_subscriptionId`  | Chainlink VRF v2.5 subscription ID                        |
| `gasLane`          | KeyHash to define the max gas price for VRF               |
| `interval`         | Time (in seconds) between raffle draws                    |
| `enteranceFee`     | Amount of ETH required to enter the raffle                |
| `callbackGasLimit` | Max gas to use for `fulfillRandomWords()` callback        |
| `vrfCoordinator`   | Address of the Chainlink VRF coordinator for your network |

---

## Example (Sepolia)

```solidity
new Raffle(
  1234,                                // Subscription ID
  0xAA77729D3466CA35AE8D664E18C1B516F3F0DCBAA83F3EBC1E1DFCB91D6E3C3E, // Gas Lane
  3600,                                // Interval: 1 hour
  0.01 ether,                          // Entry Fee
  100000,                              // Callback Gas Limit
  0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625 // VRF Coordinator
)
```

---

### ✅ Optional: Run a Script (e.g., Deploy to a Local Chain)

```bash
forge script script/DeployRaffle.s.sol --fork-url http://localhost:8545 --broadcast
```

> Replace `--fork-url` with your preferred RPC endpoint (e.g., Alchemy/Infura or Anvil).

---

## Events

- `RaffleEntered(address indexed player)`
  Emitted when a player successfully enters the raffle.

- `RequestedRaffleWinner(uint256 indexed requestId)`
  Emitted when a random number is requested.

- `WinnerPicked(address indexed winner, uint256 indexed requestId)`
  Emitted when a winner is selected and paid.

---

## Public View Functions

| Function               | Returns                         |
| ---------------------- | ------------------------------- |
| `getEnteranceFee()`    | ETH amount required to enter    |
| `getPlayer(uint256)`   | Address of a player by index    |
| `getRaffleState()`     | `OPEN` or `CALCULATING`         |
| `getNumberOfPlayers()` | Total number of current players |
| `getBalance()`         | Current ETH balance in contract |
| `getLastTimeStamp()`   | Last raffle timestamp           |
| `getRecentWinner()`    | Most recent winner address      |

---

## Errors

| Error                         | Triggered When                     |
| ----------------------------- | ---------------------------------- |
| `Raffle__raffleNotOpen()`     | Entering when raffle is not `OPEN` |
| `Raffle__transactionFailed()` | ETH transfer to winner fails       |
| `Raffle__notOwner()`          | Restricted access violation        |
| `Raffle__notEnoughETHSent()`  | Not enough ETH sent to enter       |
| `Raffle__UpkeepNotNeeded()`   | Conditions not met for upkeep      |

---

## Chainlink Resources

- [VRF v2.5 Docs](https://docs.chain.link/vrf/v2-5)
- [VRF Supported Networks](https://docs.chain.link/vrf/v2-5/supported-networks)
- [Chainlink Automation](https://docs.chain.link/chainlink-automation/introduction)

---

## Security Considerations

- Only Chainlink can fulfill the randomness request.
- Contract uses **checks-effects-interactions** pattern.
- ETH is only transferred to a winner after all state changes.

---

### 🧪 Running Tests

Run all tests using:

```bash
forge test
```

To see logs and verbose output:

```bash
forge test -vv
```

To run a specific test function:

```bash
forge test --match-test testFunctionName
```

---

## ✅ Test Coverage

### 1. **Contract Initialization**

- `testRaffleIsOpen()`
  ✔️ Ensures the raffle starts in the `OPEN` state.

- `testEnternceFeeIsCorrect()`
  ✔️ Confirms the contract stores the correct entrance fee.

---

### 2. **Entering the Raffle**

- `testPlayerCanEnterRaffle()`
  ✔️ Validates that a player can enter and is tracked correctly.

- `testSentAmount()`
  ✔️ Confirms the correct amount is reflected in contract balance after entry.

- `testEnternceFeeIsNotCorrect()`
  ❌ Reverts if the user sends less than the required fee.

- `testEnterRaffleEmitsEvent()`
  📢 Ensures the `RaffleEntered` event is emitted on entry.

- `testPlayersCantEnterWhileCalculating()`
  ❌ Players can't enter once the raffle is in the `CALCULATING` state.

- `testRecieveFunctionWorks()`
  ✔️ Checks that sending ETH directly to the contract triggers raffle entry.

---

### 3. **Upkeep Checks**

- `testCheckUpKeepReturnsFalseIfNoBalance()`
  ❌ Upkeep not needed if the contract has no balance.

- `testCheckUpKeepReturnsFalseIfRaffleIsntOpen()`
  ❌ Upkeep not needed if raffle is not open.

- `testCheckUpkeepReturnsFalseIfNotEnoughTimeHasPassed()`
  ❌ Upkeep not needed if the interval hasn’t passed.

- `testCheckUpkeepReturnsTrueIfConditionsAreMet()`
  ✔️ All upkeep conditions are met → returns `true`.

---

### 4. **Performing Upkeep**

- `testPerformUpKeepRevertsIfCheckUpkeepIsFalse()`
  ❌ Reverts if `checkUpkeep` is false.

- `testPerformUpKeepOnlyWorksIfCheckUpkeepIsTrue()`
  ✔️ Changes raffle state to `CALCULATING` when upkeep is performed.

- `testPerformUpKeepEmitsRequestId()`
  📢 Confirms that `RequestedRaffleWinner` is emitted with a non-zero request ID.

---

### 5. **VRF Fulfillment**

> These tests are skipped unless running on a local test chain (`LOCAL_CHAIN_ID`) with the mock VRF coordinator.

- `testfulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep()`
  ❌ Reverts if VRF tries to fulfill before a request is made.

- `testFulfilRandomWordsPicksAwinnerResetsAndSendsMoney()`
  ✔️ Picks a winner, resets the raffle, updates state, and sends the ETH.

---

## 📂 Project Structure

```
├── script/
│   ├── DeployRaffle.s.sol         # Deployment script
│   └── HelperConfig.s.sol         # Network config constants
├── src/
│   └── Raffle.sol                 # Main contract
├── test/
│   └── Raffle.t.sol               # Full test suite
```

---

## 🔁 Mocking VRF

- The test suite uses `VRFCoordinatorV2_5Mock` to simulate Chainlink VRF behavior locally.
- Tests involving `fulfillRandomWords()` are guarded with a `skipFork` modifier to avoid false positives on forked chains.

---

## 🏁 Final Notes

- All tests are modular and isolated.
- Logs are captured with `vm.recordLogs()` for detailed inspection.
- All state-changing actions are tested with various edge cases and assertions.

---

## License

MIT © 2025 Conrad Japhet
