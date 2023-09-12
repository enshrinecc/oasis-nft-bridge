import escrinWorker, * as escrin from '@escrin/worker';
import { Address, createPublicClient, createWalletClient, http, isHex, toHex } from 'viem';
import { PrivateKeyAccount, privateKeyToAccount } from 'viem/accounts';

import { Abutment } from './abutment.js';
import { bridge } from './bridge.js';
import { getChain } from './chains.js';

type Config = {
  emerald: ChainConfig;
  sapphire: ChainConfig;
};

type ChainConfig = {
  network: escrin.Network;
  identity: escrin.Identity;
  abutment: Address;
};

export default escrinWorker({
  async tasks(rnr: escrin.Runner): Promise<void> {
    const config = parseConfig(await rnr.getConfig());

    const permitParams = {
      permitTtl: 24 * 60 * 60, // 24 hours
      duration: 10 * 60, // 10 minutes
    };

    // Start by acquiring the submitter wallet, which will be funded and used to submit transactions.
    await rnr.acquireIdentity({ ...config.sapphire, ...permitParams });
    const omniKey = await rnr.getOmniKey(config.sapphire);
    const wallet = await deriveWallet(omniKey);
    console.debug('derived worker wallet', wallet.address);

    await rnr.acquireIdentity({ ...config.emerald, ...permitParams, recipient: wallet.address });
    await rnr.acquireIdentity({ ...config.sapphire, ...permitParams, recipient: wallet.address });
    console.debug('acquired worker submitter identities');

    const emeraldAbutment = await makeAbutment(config.emerald, wallet);
    const sapphireAbutment = await makeAbutment(config.sapphire, wallet);

    try {
      console.log('emerald 🌉 sapphire');
      await bridge(emeraldAbutment, sapphireAbutment);
    } catch (e: any) {
      console.error('failed to bridge from emerald to sapphire', e);
    }
    try {
      console.log('sapphire 🌉 emerald');
      await bridge(sapphireAbutment, emeraldAbutment);
    } catch (e: any) {
      console.error('failed to bridge from sapphire to emerald', e);
    }
  },
});

function parseConfig(config: Record<string, unknown>): Config {
  const { emerald, sapphire } = config;
  return {
    emerald: parseChainConfig('emerald', emerald),
    sapphire: parseChainConfig('sapphire', sapphire),
  };
}

function parseChainConfig(name: string, config: unknown): ChainConfig {
  try {
    if (!config) throw new Error('missing config object');
    if (typeof config !== 'object') throw new Error('invalid config object');
    const { network, identity, abutment } = config as Record<string, unknown>;
    if (!isHex(abutment)) throw new Error('invalid abutment address');
    return {
      network: escrin.parseNetwork(network),
      identity: escrin.parseIdentity(identity),
      abutment,
    };
  } catch (e: any) {
    throw new escrin.ApiError(500, `failed to parse ${name} config: ${e.message}`);
  }
}

async function deriveWallet(omniKey: CryptoKey): Promise<PrivateKeyAccount> {
  const key = await crypto.subtle.deriveBits(
    {
      name: 'HKDF',
      hash: 'SHA-512-256',
      salt: new Uint8Array(),
      info: new TextEncoder().encode('ai-rose/bridge'),
    },
    omniKey,
    256,
  );
  return privateKeyToAccount(toHex(new Uint8Array(key)));
}

async function makeAbutment(config: ChainConfig, wallet: PrivateKeyAccount): Promise<Abutment> {
  const chain = getChain(config.network.chainId, config.network.rpcUrl);
  const publicClient = createPublicClient({ chain, transport: http() });

  const fundingWei = await publicClient.getBalance({ address: wallet.address });
  const funding = Number(fundingWei / BigInt(1e9)) / 1e9;
  if (funding < 0.01)
    throw new escrin.ApiError(
      500,
      `submitter wallet ${wallet.address} is unfunded on chain ${chain.id}`,
    );

  const walletClient = createWalletClient({ account: wallet, chain, transport: http() });
  return new Abutment(publicClient, walletClient, wallet, config.abutment);
}
