// MITMs the Web3 gateway to fix compatibility issues with tooling.
// This one has been modified to appease Foundry:
// * returns `0x` instead of `0x0` from `eth_getStorageAt`
// * delays `eth_getTransactionByHash` to prevent error about the tx being dropped from the mempool

import http from 'node:http';
import https from 'node:https';
import { Readable } from 'node:stream';

if (!process.argv[2]) {
  console.error(`usage: node web3-proxy.mjs <upstream gateway hostname>`);
  process.exit(1);
}

const hooks = {
  '*': (req, _res, next) => {
    console.log(req);
    next();
  },
  eth_getStorageAt({ jsonrpc, id }, res) {
    res.writeHead(200, { 'content-type': 'application/json' }).end(
      JSON.stringify({
        jsonrpc,
        id,
        result: '0x',
      }),
    );
  },
  eth_getTransactionByHash(_req, _res, next) {
    setTimeout(next, 7000);
  },
};

const server = http.createServer((req, res) => {
  const abort = (e) => {
    res
      .writeHead(500)
      .end(JSON.stringify({ error: e }))
      .on('error', () => {});
  };

  const defaultHandler = (_req, _res, next) => next();

  const bodyChunks = [];
  req
    .on('data', (chunk) => bodyChunks.push(chunk))
    .on('end', () => {
      const req = JSON.parse(Buffer.concat(bodyChunks));
      const proxyPass = () => {
        const proxyReq = https.request(
          {
            hostname: process.argv[2],
            port: '443',
            path: '/',
            method: 'POST',
            headers: {
              'content-type': 'application/json',
            },
          },
          (r) => r.pipe(res),
        );
        Readable.from(bodyChunks).pipe(proxyReq).on('error', abort);
      };
      (hooks['*'] ?? defaultHandler)(req, res, () => {
        try {
          (hooks[req.method] ?? defaultHandler)(req, res, proxyPass);
        } catch (e) {
          abort(e);
        }
      });
    })
    .on('error', abort);
});

server.listen(8545);