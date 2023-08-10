import { Address } from 'viem';

import { Abutment, ActionEffect, BridgeAction, Presence } from './abutment.js';

export async function bridge(from: Abutment, to: Abutment): Promise<void> {
  const supportedCollections = await from.getSupportedCollections();
  const releaseActions: BridgeAction[] = [];
  const lockActions: BridgeAction[] = [];
  for (const collection of supportedCollections) {
    const pendingTokens = await getCollectionPendingTokens(from, collection);
    if (pendingTokens.length === 0) continue;
    const remote = await from.getRemoteToken(collection);
    for (const { id, owner } of pendingTokens) {
      releaseActions.push({
        token: remote,
        tokenId: id,
        recipient: owner,
        effect: ActionEffect.Release,
      });
      lockActions.push({
        token: collection,
        tokenId: id,
        recipient: owner,
        effect: ActionEffect.Lock,
      });
    }
  }

  await submit('🔓', to, releaseActions);
  await submit('🔒', from, lockActions);
}

async function submit(
  actionName: string,
  abutment: Abutment,
  actions: BridgeAction[],
): Promise<void> {
  try {
    if (actions.length > 0) {
      console.log(`${actionName} ${actions.length} tokens`);
      const tx = await abutment.submitTaskResults(actions);
      await tx.wait();
    }
  } catch (e: any) {
    console.error(`failed to ${actionName} tokens:`, e);
    throw e;
  }
}

async function getCollectionPendingTokens(
  abutment: Abutment,
  collection: Address,
): Promise<Array<{ owner: Address; id: bigint }>> {
  const abutmentTokens = await abutment.getAbutmentTokens(collection);
  const tokenStatuses = await abutment.getTokenStatuses(collection, abutmentTokens);
  const pendingTokens: Array<{ owner: Address; id: bigint }> = [];
  for (let i = 0; i < abutmentTokens.length; i++) {
    if (tokenStatuses[i].presence !== Presence.Abutment) continue;
    pendingTokens.push({
      id: abutmentTokens[i],
      owner: tokenStatuses[i].owner,
    });
  }
  return pendingTokens;
}
