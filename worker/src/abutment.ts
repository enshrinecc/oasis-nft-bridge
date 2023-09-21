import {
  Account,
  Address,
  BlockNotFoundError,
  Chain,
  Hash,
  PublicClient,
  TransactionNotFoundError,
  Transport,
  WalletClient,
  encodeAbiParameters,
  parseGwei,
} from 'viem';

import { Abutment as AbutmentAbi } from './abis.js';

export class Abutment {
  constructor(
    private readonly publicClient: PublicClient<Transport, Chain>,
    private readonly walletClient: WalletClient<Transport, Chain, Account>,
    private readonly walletAccount: Account,
    public readonly address: Address,
  ) {}

  public async getSupportedCollections(): Promise<readonly Address[]> {
    return this.publicClient.readContract({
      address: this.address,
      abi: AbutmentAbi,
      functionName: 'getSupportedCollections',
    });
  }

  public async getRemoteToken(collection: Address): Promise<Address> {
    return this.publicClient.readContract({
      address: this.address,
      abi: AbutmentAbi,
      functionName: 'getRemote',
      args: [collection],
    });
  }

  public async getAbutmentTokens(collection: Address): Promise<readonly bigint[]> {
    return this.publicClient.readContract({
      address: this.address,
      abi: AbutmentAbi,
      functionName: 'getHeldTokens',
      args: [this.address, collection],
    });
  }

  public async getTokenStatuses(
    collection: Address,
    tokens: readonly bigint[],
  ): Promise<readonly TokenStatus[]> {
    return this.publicClient.readContract({
      address: this.address,
      abi: AbutmentAbi,
      functionName: 'getTokenStatuses',
      args: [collection, tokens],
    });
  }

  public async submitTaskResults(actions: readonly BridgeAction[]): Promise<Transaction> {
    const taskIds: bigint[] = actions.map((_, i) => BigInt(i));
    const report = encodeAbiParameters(
      [
        {
          type: 'tuple[]',
          internalType: 'struct BridgeAction[]',
          name: 'actions',
          components: [
            { name: 'token', type: 'address' },
            { name: 'tokenId', type: 'uint256' },
            { name: 'effect', type: 'uint8', internalType: 'enum ActionEffect' },
            { name: 'recipient', type: 'address' },
          ],
        },
      ],
      [actions],
    );
    const request = {
      chain: this.publicClient.chain,
      account: this.walletAccount,
      address: this.address,
      abi: AbutmentAbi,
      functionName: 'acceptTaskResults',
      args: [taskIds, '0x' /* proof */, report],
      type: 'legacy',
      gasPrice: BigInt(100e9),
    } as const;
    const gas = await this.publicClient.estimateContractGas(request);
    if (Math.abs(this.publicClient.chain.id - 0x5afe) > 1) {
      // Does not work on Sapphire due to wrapper not supporting signed queries.
      const { result: selector } = await this.publicClient.simulateContract({ ...request, gas });
      if (selector.quantifier !== 1 /* all */)
        throw new Error(`task results not accepted. quantifier=${selector.quantifier}`);
    }
    const hash = await this.walletClient.writeContract({ ...request, gas });
    return new Transaction(hash, this.publicClient);
  }
}

class Transaction {
  constructor(public readonly hash: Hash, private readonly client: PublicClient) {}

  async wait(): Promise<void> {
    let retriesRemaining = 3;
    while (true) {
      try {
        const { status } = await this.client.waitForTransactionReceipt({ hash: this.hash });
        if (status !== 'success') throw new Error(`failed to post ${this.hash}`);
        return;
      } catch (e: any) {
        if (e instanceof BlockNotFoundError || e instanceof TransactionNotFoundError) {
          if (retriesRemaining === 0) throw e;
          retriesRemaining--;
          await new Promise((resolve) => setTimeout(resolve, 2_000));
          continue;
        }
        throw e;
      }
    }
  }
}

export type TokenStatus = {
  owner: Address;
  presence: Presence;
};

export enum Presence {
  Unknown = 0,
  Absent = 1,
  Abutment = 2,
  Wallet = 3,
}

export type BridgeAction = {
  token: Address;
  tokenId: bigint;
  effect: ActionEffect;
  recipient: Address;
};

export enum ActionEffect {
  Lock = 1,
  Release = 2,
}
