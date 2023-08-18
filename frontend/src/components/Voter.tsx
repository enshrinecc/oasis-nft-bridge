import { useMemo } from 'react';
import {
  useAccount,
  useContractRead,
  useContractWrite,
  useNetwork,
  usePrepareContractWrite,
  useWaitForTransaction,
} from 'wagmi';

import { Abutment as AbutmentABI } from '../abis.js';
import {
  SupportedChain,
  SupportedCollection,
  chainIsSupported,
  collectionIsSupported,
  getAbutment,
  getCollectionAddr,
} from '../collections.js';
import { useVoteStatus } from '../hooks/useVoteStatus.js';

export function Voter({ collection }: { collection: SupportedCollection }) {
  const { address, isConnected } = useAccount();
  const { chain } = useNetwork();

  const { data: voteStatus } = useVoteStatus(chain?.id, collection);

  const collectionAddr = useMemo(
    () => getCollectionAddr(collection!, chain?.id as SupportedChain)!,
    [collection, chain],
  );

  const abutmentAddr = useMemo(() => (chain ? getAbutment(chain.id) : undefined), [chain]);

  const votingTokens = useContractRead({
    address: abutmentAddr,
    abi: AbutmentABI,
    functionName: 'getVotingTokens',
    args: [address!, collectionAddr],
    enabled:
      isConnected && chainIsSupported(chain?.id) && collectionIsSupported(collection, chain?.id!),
  });

  const {
    config,
    error: prepareError,
    isLoading: isPreparing,
  } = usePrepareContractWrite({
    address: abutmentAddr,
    abi: AbutmentABI,
    functionName: 'vote',
    args: [collectionAddr, votingTokens.data!],
    enabled:
      isConnected && chainIsSupported(chain?.id) && collectionIsSupported(collection, chain?.id!),
  });
  const { write, data, error, isLoading: isWriting, isError } = useContractWrite(config);
  const { isLoading: isWaiting, isSuccess: hasVoted } = useWaitForTransaction({ hash: data?.hash });

  const isPending = useMemo(
    () => isPreparing || isWriting || isWaiting,
    [isPreparing, isWriting, isWriting],
  );

  return (
    <div>
      <p>Bridging must be approved by a majority vote.</p>
      <p>1 token = 1 vote</p>
      <h2 className="text-xl mt-3">Votes Cast</h2>
      <p className="text-2xl whitespace-nowrap mt-1 mb-3">
        <span className="text-sapphire">{voteStatus?.[0].toString() ?? 'unknown'}</span>
        &nbsp;<span>/</span>&nbsp;
        <span>{voteStatus?.[1].toString() ?? 'unknown'}</span>
      </p>
      {(votingTokens.data?.length ?? 0) > 0 && !hasVoted && (
        <button
          disabled={isPending}
          className={`action ${isPending && !hasVoted ? 'pending' : ''}`}
          onClick={() => write?.()}
        >
          Cast&nbsp;{votingTokens.data!.length}&nbsp;
          {`vote${votingTokens.data!.length > 1 ? 's' : ''}`}
        </button>
      )}

      {isError && !/rejected/g.test(error?.message ?? '') && (
        <div className="overflow-scroll">{error?.message}</div>
      )}
      {prepareError && <div className="overflow-scroll">{prepareError?.message}</div>}
    </div>
  );
}
