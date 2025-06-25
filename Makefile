-include .env

.PHONY : all test deploy
build:;forge build

test:; forge test
install:; forge install cyfrin/foundry-devops@0.2.2 && forge install smartcontractkit/chainlink@1.1.1 && forge install foundry-rs/forge-std@1.8.2 && forge install transmissions11/solmate@v6


deploy-sepolia:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA)  --account sepolia --broadcast  -vvvv
