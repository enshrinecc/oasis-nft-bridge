const fs = require('fs');

const { abi: AbutmentAbi } = require('./out/Abutment.sol/Abutment.json');

const abis = `export const Abutment = ${JSON.stringify(AbutmentAbi, null, 2)} as const;`;

fs.writeFileSync('./abis.ts', abis);
