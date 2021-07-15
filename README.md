# contracts.demo

Contracts for Fluidex demo, using hardhat local node for now.

```
yarn install

// in one terminal
npx hardhat node

// set GENESIS_ROOT env
export GENESIS_ROOT={uint256}

// in another terminal
npx hardhat run scripts/deploy.js --network localhost
```
