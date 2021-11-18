import { run, ethers } from "hardhat";

import {default as proof} from './recursive_proof.json';

async function main() {

    await run('compile');

    const verifierFactory = await ethers.getContractFactory("KeysWithPlonkVerifier");
    const verifier = await verifierFactory.deploy();
    await verifier.deployed();
    console.log("Verifier deployed to:", verifier.address);
    
    const ret = await verifier.verifyAggregatedProof(...proof, {gasLimit : 30000000})

    console.log(ret)
}


main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
