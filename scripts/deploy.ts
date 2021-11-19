import { Account } from "fluidex.js";
import { run, ethers } from "hardhat";
import * as hre from "hardhat";
import { default as tokens} from "../tokens";
import { getTestAccount } from "./accounts";

const loadAccounts = () => Array.from(botsIds).map((user_id) => Account.fromMnemonic(getTestAccount(user_id).mnemonic));
const botsIds = [1, 2, 3, 4, 5];
const accounts = loadAccounts();

async function main() {
  await run('compile');

  const verifierFactory = await ethers.getContractFactory("KeyedVerifier");
  const verifier = await verifierFactory.deploy();
  await verifier.deployed();
  console.log("Verifier deployed to:", verifier.address);

  const fluidexFactory = await ethers.getContractFactory("FluiDexDemo");
  const genesisRoot = process.env.GENESIS_ROOT;
  console.log("genesisRoot:", genesisRoot);
  const fluiDex = await fluidexFactory.deploy(genesisRoot, verifier.address);
  await fluiDex.deployed();
  console.log("FluiDex deployed to:", fluiDex.address);

  const registerUser = fluiDex.functions.registerUser;
  for(const account of accounts) {
    await registerUser(account.ethAddr, account.bjjPubKey);
    console.log(`register user ${account.bjjPubKey}`);
  }

  const fluiDexDelegateFactory = await ethers.getContractFactory("FluiDexDelegate");
  const fluiDexDelegate = await fluiDexDelegateFactory.deploy(fluiDex.address);
  await fluiDexDelegate.deployed();
  console.log("FluiDexDelegate deployed to:", fluiDexDelegate.address);

  const DELEGATE_ROLE = await fluiDex.callStatic.DELEGATE_ROLE();
  await fluiDex.functions.grantRole(DELEGATE_ROLE, fluiDexDelegate.address);
  console.log("grant DELEGATE_ROLE to FluiDexDelegate");

  const addToken = fluiDexDelegate.functions.addToken;
  for (const {name, address} of Array.from(tokens)) {
    await addToken(address);
    console.log(`add ${name} token at`, address);
  }

  // skip verify on localhost
  if (hre.network.name !== "localhost") {
    await run('verify', {
      address: verifier.address,
      contract: "contracts/Verifier.sol:KeyedVerifier",
    });
    await run('verify', {
      address: fluiDex.address,
      contract: "contracts/FluiDex.sol:FluiDexDemo",
      constructorArgsParams: [genesisRoot, verifier.address],
    });
    await run('verify', {
      address: fluiDexDelegate.address,
      contract: "contracts/FluiDexDelegate.sol:FluiDexDelegate",
      constructorArgsParams: [fluiDex.address],
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
