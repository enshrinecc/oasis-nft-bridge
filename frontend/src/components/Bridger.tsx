import { erc721ABI } from '@wagmi/core';
import { useMemo } from 'react';
import Loader from 'react-spinners/GridLoader';
import {
  useAccount,
  useContractRead,
  useContractWrite,
  useNetwork,
  usePrepareContractWrite,
  useWaitForTransaction,
} from 'wagmi';

import { Abutment as AbutmentABI } from '../abi.js';
import {
  SupportedChain,
  SupportedCollection,
  chainIsSupported,
  collectionIsSupported,
  getAbutment,
  getCollectionAddr,
} from '../collections.js';

export function Bridger({ collection }: { collection: SupportedCollection }) {
  const { address, isConnected } = useAccount();
  const { chain } = useNetwork();

  const collectionAddr = useMemo(
    () => getCollectionAddr(collection!, chain?.id as SupportedChain)!,
    [collection, chain],
  );

  const abutmentAddr = useMemo(() => (chain ? getAbutment(chain.id) : undefined), [chain]);

  const {
    data: tokens,
    isLoading,
    isSuccess,
    isError,
    error,
  } = useContractRead({
    address: abutmentAddr,
    abi: AbutmentABI,
    functionName: 'getTokensByHolder',
    args: [address!, collectionAddr],
    enabled:
      isConnected && chainIsSupported(chain?.id) && collectionIsSupported(collection, chain?.id!),
    watch: true,
  });

  const trackedTokens = useMemo(
    () => tokens?.filter(({ presence }) => presence !== 1 /* absent */) ?? [],
    [tokens]
  );

  return (
    <>
      {isLoading && <Loader color="#8ab1cf" loading={true} size={40} />}
      {isSuccess &&
        (trackedTokens.length === 0 ? (
          <p className="mt-8 mb-4 max-w-prose">
            You do not have any tokens available to be bridged on this network.
          </p>
        ) : (
          <div className="flex justify-around flex-wrap">
            {trackedTokens.map(({ id, presence }) => (
              <Token key={Number(id)} collection={collection} id={id} presence={presence} />
            ))}
          </div>
        ))}

      {isError && <div className="overflow-scroll">{error?.message}</div>}
    </>
  );
}

function Token({
  collection,
  id,
  presence,
}: {
  collection: SupportedCollection;
  id: bigint;
  presence: number;
}) {
  const { address, isConnected } = useAccount();
  const { chain } = useNetwork();

  const { data: tokenURI, isSuccess: tokenURILoaded } = useContractRead({
    address: getCollectionAddr(collection, chain?.id),
    abi: erc721ABI,
    functionName: 'tokenURI',
    args: [id],
    select: (tokenURI: string) => {
      const url = new URL(tokenURI);
      if (url.pathname.startsWith('/ipfs')) {
        url.hostname = 'ipfs.io';
      }
      return url.toString();
    },
  });

  const { config, isLoading: isPreparing } = usePrepareContractWrite({
    address: getCollectionAddr(collection, chain?.id),
    abi: erc721ABI,
    functionName: 'safeTransferFrom',
    args: [address!, getAbutment(chain?.id)!, id],
    enabled: false && isConnected && collectionIsSupported(collection, chain?.id),
  });
  const { data, write, isLoading: isWriting } = useContractWrite(config);
  const { isLoading: isWaiting } = useWaitForTransaction({ hash: data?.hash });

  const isPending = useMemo(
    () => isPreparing || isWriting || isWaiting || presence === 2,
    [isPreparing, isWriting, isWriting, presence],
  );

  return (
    <>
      {tokenURILoaded ? (
        <>
          <div
            className={`nft-image-container my-4 m-2 flex flex-col items-center justify-around ${
              presence !== 2 ? 'cursor-pointer' : ''
            }`}
            onClick={presence !== 2 ? write : () => {}}
          >
            <div className="relative">
              {isPending && (
                <div className="h-full w-full absolute backdrop-blur-[2px] z-0 flex items-center justify-center">
                  <Loader size="20px" color="#8ab1cf" />
                </div>
              )}
              <img src={`${tokenURI}.png`} className="p-1 nft-image max-w-none w-44" />
            </div>
          </div>
        </>
      ) : (
        <Loader color="#8ab1cf" />
      )}
    </>
  );
}
