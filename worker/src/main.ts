import escrinWorker, { ApiError, EscrinRunner } from '@escrin/worker';

import { Address, createPublicClient, createWalletClient, http, toHex } from 'viem';
import { PrivateKeyAccount, privateKeyToAccount } from 'viem/accounts';

import { Abutment } from './abutment.js';
import { bridge } from './bridge';
import getChain from './chains.js';

type Config = {
  env: 'local' | 'mainnet' | 'testnet';
  emerald: NetworkConfig;
  sapphire: NetworkConfig;
};

type NetworkConfig = {
  gateway: string;
  abutment: Address;
};

escrinWorker({
  async tasks(rnr: EscrinRunner): Promise<void> {
    const config = validateConfig(await rnr.getConfig());

    const keystore = config.env === 'local' ? 'local' : (`sapphire-${config.env}` as const);
    const wallet = await deriveWallet(await rnr.getOmniKey(keystore));

    const emeraldAbutment = await makeAbutment('emerald', config, wallet);
    const sapphireAbutment = await makeAbutment('sapphire', config, wallet);

    try {
      await bridge(emeraldAbutment, sapphireAbutment);
    } catch (e: any) {
      console.error('failed to bridge from emerald to sapphire', e);
    }
    try {
      await bridge(sapphireAbutment, emeraldAbutment);
    } catch (e: any) {
      console.error('failed to bridge from sapphire to emerald', e);
    }
  },
});

function validateConfig(config: any): Config {
  try {
    if (!config.emerald.gateway || !config.emerald.abutment) {
      throw new ApiError(500, `missing or invalid emerald config`);
    }
    if (!config.sapphire.gateway || !config.sapphire.abutment) {
      throw new ApiError(500, `missing or invalid sapphire config`);
    }
  } catch (e: any) {
    console.error('failed to validate config:', e);
    throw e;
  }
  return config;
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

async function makeAbutment(
  net: 'emerald' | 'sapphire',
  config: Config,
  wallet: PrivateKeyAccount,
): Promise<Abutment> {
  const chain = config.env === 'local' ? getChain('local') : getChain(`${net}-${config.env}`);
  const transport = http(config[net].gateway);
  const publicClient = createPublicClient({ chain, transport });
  const walletClient = createWalletClient({ account: wallet, chain, transport });
  return new Abutment(publicClient, walletClient, config[net].abutment);
}
