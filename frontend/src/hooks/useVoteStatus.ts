import { useContractRead } from 'wagmi';

import {
  SupportedCollection,
  chainIsSupported,
  collectionIsSupported,
  getAbutment,
  getCollectionAddr,
} from '../collections.js';
import { Abutment as AbutmentABI } from '../abi.js';

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
