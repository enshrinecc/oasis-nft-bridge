import { useEffect, useMemo, useState } from 'react';
import { Address, useContractRead, useNetwork } from 'wagmi';

import { Abutment as AbutmentABI } from './abi.js';

const abutments: Partial<Record<SupportedChain, Address>> = {
  1337: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
  31337: '0x5FC8d32690cc91D4c39d9d3abcBD16989F875707',
};

const collections: Record<SupportedCollection, Collection> = {
  'ai-rose': {
    name: 'AI Rose',
    chains: {
      // 0x5aff: '0x',
      // 0xa515: '0x',
    },
  },
  test: {
    name: 'Test Token',
    chains: {
      1337: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
      31337: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    },
  },
};

export type SupportedCollection = 'test' | 'ai-rose';
export type SupportedChain = 0x5aff | 0xa515 | 0x5afe | 0xa516 | 1337 | 31337;

export type Collection = {
  name: string;
  chains: Partial<Record<SupportedChain, Address>>;
};

export function getCollections(chainId: number): Record<SupportedChain, { name: string }> {
  return Object.fromEntries(
    Object.entries(collections).filter(([_, coll]) => chainId in coll.chains),
  ) as Record<SupportedChain, Collection>;
}

export function getAbutment(chainId: number | undefined): Address | undefined {
  return chainIsSupported(chainId) ? abutments[chainId] : undefined;
}

export function getCollectionAddr(id: string, chainId: number | undefined): Address | undefined {
  return chainIsSupported(chainId) && collectionIsSupported(id, chainId)
    ? collections[id].chains[chainId]
    : undefined;
}

export function collectionIsSupported(
  id: string | undefined,
  chainId: number | undefined,
): id is SupportedCollection {
  return (
    chainIsSupported(chainId) &&
    id !== undefined &&
    id in collections &&
    chainId in collections[id as SupportedCollection].chains
  );
}

export function chainIsSupported(chainId: number | undefined): chainId is SupportedChain {
  return (
    chainId === 0x5aff ||
    chainId === 0xa515 ||
    chainId === 0x5afe ||
    chainId === 0xa516 ||
    (import.meta.env.MODE === 'development' && (chainId === 1337 || chainId === 31337))
  );
}

export function getNetworkClassification(chainId: SupportedChain): 'emerald' | 'sapphire' {
  if (chainId === 0x5aff || chainId === 0x5afe || chainId === 31337) return 'sapphire';
  return 'emerald';
}

export function useVoteStatus(
  chainId: number | undefined,
  collection: SupportedCollection | undefined,
) {
  return useContractRead({
    address: getAbutment(chainId),
    abi: AbutmentABI,
    functionName: 'getVoteStatus',
    args: [getCollectionAddr(collection!, chainId)!],
    enabled: chainIsSupported(chainId) && collectionIsSupported(collection, chainId),
    cacheOnBlock: true,
    watch: true,
  });
}
