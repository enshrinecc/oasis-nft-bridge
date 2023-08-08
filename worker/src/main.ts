import escrinWorker, { ApiError, EscrinRunner } from '@escrin/worker';

import {
  Address,
  PublicClient,
  WalletClient,
  createPublicClient,
  createWalletClient,
  encodeAbiParameters,
  http,
  parseGwei,
  toHex,
} from 'viem';
import { PrivateKeyAccount, privateKeyToAccount } from 'viem/accounts';

import { AbutmentAbi } from '@enshrine/nft-bridge-evm';

import { estimateContractGas } from 'viem/dist/types/actions/public/estimateContractGas';
import getChain from './chains';

escrinWorker({
  async tasks(rnr: EscrinRunner): Promise<void> {
    const config = validateConfig(await rnr.getConfig());

    const keystore = config.env === 'local' ? 'local' : (`sapphire-${config.env}` as const);
    const wallet = await deriveWallet(await rnr.getOmniKey(keystore as any));

    const emeraldEp = await makeContractAndClient('emerald', config, wallet);
    const sapphireEp = await makeContractAndClient('sapphire', config, wallet);

    try {
      await bridge(emeraldEp, sapphireEp);
    } catch (e: any) {
      console.error('failed to bridge from emerald to sapphire', e);
    }
    try {
      await bridge(sapphireEp, emeraldEp);
    } catch (e: any) {
      console.error('failed to bridge from sapphire to emerald', e);
    }
  },
});

async function makeContractAndClient(
  net: 'emerald' | 'sapphire',
  config: Config,
  wallet: PrivateKeyAccount,
): Promise<ContractClient> {
  const chain = config.env === 'local' ? getChain('local') : getChain(`${net}-${config.env}`);
  const transport = http(config[net].gateway);
  const publicClient = createPublicClient({ chain, transport });
  const walletClient = createWalletClient({ account: wallet, chain, transport });
  const [account] = await walletClient.requestAddresses();
  return {
    public: publicClient,
    wallet: walletClient,
    abutment: config[net].abutment,
    account,
  };
}

type ContractClient = {
  public: PublicClient;
  wallet: WalletClient;
  abutment: Address;
  account: Address;
};

async function bridge(from: ContractClient, to: ContractClient): Promise<void> {
  const supportedCollections = await from.public.readContract({
    address: from.abutment,
    abi: AbutmentAbi,
    functionName: 'getSupportedCollections',
  });
  const taskIds = [];
  const lockActions: BridgeAction[] = [];
  const releaseActions: BridgeAction[] = [];
  for (const collection of supportedCollections) {
    let nextTaskId = 0n;
    for (const { id, owner } of await getCollectionPendingTokens(from, collection)) {
      taskIds.push(nextTaskId++);
      const action: Omit<BridgeAction, 'effect'> = {
        token: collection,
        tokenId: id,
        recipient: owner,
      };
      lockActions.push({ ...action, effect: 1 });
      releaseActions.push({ ...action, effect: 2 });
    }
  }
  await submitTaskResults('release', to, taskIds, releaseActions);
  await submitTaskResults('lock', from, taskIds, lockActions);
}

type BridgeAction = {
  token: Address;
  tokenId: bigint;
  effect: 1 | 2; // lock | release
  recipient: Address;
};

async function submitTaskResults(
  action: string,
  to: ContractClient,
  taskIds: bigint[],
  actions: BridgeAction[],
): Promise<void> {
  const report = encodeAbiParameters(
    [
      {
        type: 'tuple',
        name: 'actions',
        components: [
          { name: 'token', type: 'address' },
          { name: 'tokenId', type: 'uint256' },
          { name: 'effect', type: 'uint8' },
          { name: 'recipient', type: 'address' },
        ],
      },
    ],
    [actions],
  );
  const request = {
    chain: to.public.chain,
    account: to.account,
    address: to.abutment,
    abi: AbutmentAbi,
    functionName: 'acceptTaskResults',
    args: [taskIds, '0x' /* proof */, report],
    type: 'legacy',
    gasPrice: parseGwei('100'),
  } as const;
  const gas = await to.public.estimateContractGas(request);
  const hash = await to.wallet.writeContract({ ...request, gas });
  console.log(`submitted request to ${action} tokens`, hash);
  const receipt = await to.public.waitForTransactionReceipt({ hash });
  if (receipt.status !== 'success') throw new Error('failed to lock tokens');
}

async function getCollectionPendingTokens(
  client: ContractClient,
  collection: Address,
): Promise<Array<{ owner: Address; id: bigint }>> {
  const abutmentTokens: readonly bigint[] = await client.public.readContract({
    address: client.abutment,
    abi: AbutmentAbi,
    functionName: 'getAbutmentTokens',
    args: [collection],
  });
  const tokenStatuses = await client.public.readContract({
    address: client.abutment,
    abi: AbutmentAbi,
    functionName: 'getTokenStatuses',
    args: [collection, abutmentTokens],
  });
  const pendingTokens: Array<{ owner: Address; id: bigint }> = [];
  for (let i = 0; i < abutmentTokens.length; i++) {
    if (tokenStatuses[i].presence !== 2 /* abutment */) continue;
    pendingTokens.push({
      id: abutmentTokens[i],
      owner: tokenStatuses[i].owner,
    });
  }
  return pendingTokens;
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

type Config = {
  env: 'local' | 'mainnet' | 'testnet';
  emerald: NetworkConfig;
  sapphire: NetworkConfig;
};

type NetworkConfig = {
  gateway: string;
  abutment: Address;
};

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
