import { useContractRead } from 'wagmi';

import {
  SupportedCollection,
  chainIsSupported,
  collectionIsSupported,
  getAbutment,
  getCollectionAddr,
} from '../collections.js';
import { Abutment as AbutmentABI } from '../abis.js';

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
    cacheTime: 20 * 60 * 1_000, // 20 minutes
    staleTime: 20 * 60 * 1_000, // 20 minutes
    watch: true,
  });
}
