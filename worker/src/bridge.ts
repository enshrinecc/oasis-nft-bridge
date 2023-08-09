import { Address } from 'viem';

import { Abutment, ActionEffect, BridgeAction, Presence } from './abutment.js';

export async function bridge(from: Abutment, to: Abutment): Promise<void> {
  const supportedCollections = await from.getSupportedCollections();
  const actions: Omit<BridgeAction, 'effect'>[] = [];
  for (const collection of supportedCollections) {
    for (const { id, owner } of await getCollectionPendingTokens(from, collection)) {
      actions.push({
        token: collection,
        tokenId: id,
        recipient: owner,
      });
    }
  }
  try {
    const tx = await to.submitTaskResults(
      actions.map((action) => ({ ...action, effect: ActionEffect.Release })),
    );
    await tx.wait();
  } catch (e: any) {
    console.error('failed to release tokens:', e);
    throw e;
  }
  try {
    const tx = await from.submitTaskResults(
      actions.map((action) => ({ ...action, effect: ActionEffect.Lock })),
    );
    await tx.wait();
  } catch (e: any) {
    console.error('failed to lock tokens:', e);
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
