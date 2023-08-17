import { useMemo, useState } from 'react';
import { useAccount, useContractRead, useNetwork } from 'wagmi';
import Loader from 'react-spinners/GridLoader';

import { Connect } from './components/Connect';
import { Connected } from './components/Connected';
import { NetworkSwitcher } from './components/NetworkSwitcher';
import { CollectionChooser } from './components/CollectionChooser';

import { Abutment as AbutmentABI } from './abi.js';
import {
  SupportedChain,
  SupportedCollection,
  chainIsSupported,
  collectionIsSupported,
  getAbutment,
  getCollectionAddr,
  getNetworkClassification,
} from './collections.js';
import './index.css';

export function App() {
  const { address, isConnected } = useAccount();
  const { chain } = useNetwork();

  const [collection, setCollection] = useState<SupportedCollection | undefined>();

  const abutmentAddr = useMemo(() => (chain ? getAbutment(chain.id) : undefined), [chain]);

  const collectionVoteStatus = useContractRead({
    address: abutmentAddr,
    abi: AbutmentABI,
    functionName: 'getVoteStatus',
    args: [getCollectionAddr(collection!, chain?.id as SupportedChain)!],
    enabled: chainIsSupported(chain?.id) && collectionIsSupported(collection, chain?.id!),
    watch: true,
  });

  const votingPower = useContractRead({
    address: abutmentAddr,
    abi: AbutmentABI,
    functionName: 'getVotingPower',
    args: [address!, getCollectionAddr(collection!, chain?.id as SupportedChain)!],
    enabled:
      isConnected && chainIsSupported(chain?.id) && collectionIsSupported(collection, chain?.id!),
    select: (p) => Number(p),
    watch: true,
  });

  const collectionStatus = useMemo<'active' | 'inactive' | 'unknown'>(() => {
    if (
      !chainIsSupported(chain?.id) ||
      collectionVoteStatus.isError ||
      collectionVoteStatus.data === undefined
    )
      return 'unknown';
    const [votes, quorum] = collectionVoteStatus.data;
    if (getNetworkClassification(chain?.id!) === 'emerald') {
      return votes >= quorum ? 'active' : 'inactive';
    } else {
      return votes >= quorum ? 'inactive' : 'active';
    }
  }, [chain, collectionVoteStatus]);

  return (
    <>
      <header className="hero-image text-center">
        <div className="py-4">
          <img
            width="70px"
            src="https://enshrine.ai/favicon.svg"
            className="mx-auto -mb-2 bg-night/[.9] rounded-t-xl p-3 logo-clip"
          />
          <div className="text-center bg-night/[.9] inline-block rounded-xl py-2 px-4">
            <h1 className="text-3xl font-medium text-white hero-text">NFT Bridge</h1>
          </div>
        </div>
        <p className="max-w-sm text-white text-2xl mx-auto rounded-xl bg-night/[.9] py-4">
          Securely bridge Oasis NFTs using{' '}
          <a href="https://escrin.org" className="text-escrin underline underline-offset-8">
            <span className="whitespace-nowrap">
              <img
                width="30px"
                src="https://escrin.org/logo.svg"
                className="inline-block -translate-y-1"
              />
              Escrin Smart Workers
            </span>
          </a>
        </p>
        <a
          href="#app"
          className="inline-block bg-gradient-to-t from-40% from-green-500 text-3xl px-8 py-5 rounded-b-xl border-b-2 border-night mt-5 text-night font-medium hover:py-7 active:-translate-y-4 transition-all"
        >
          <div className="translate-y-1/2">Go</div>
        </a>
      </header>
      <main className="app">
        <a id="app"></a>
        <div className="app-content">
          <div className="app-card">
            <h1>Step 1: Connect Your Wallet</h1>
            {isConnected && (
              <span className="font-mono inline-block w-3/4 truncate text-ellipsis">
                {isConnected && address}
              </span>
            )}
            <Connect />
          </div>

          <Connected>
            <div className="app-card">
              <h1>2. Choose a source network</h1>
              <NetworkSwitcher />
            </div>

            {!chain?.unsupported && (
              <div className="app-card">
                <h1>3. Choose a collection</h1>
                <CollectionChooser collection={collection} setCollection={setCollection} />
              </div>
            )}

            {collection && (
              <div className="app-card">
                {collectionStatus === 'active' ? (
                  <>
                    <h1>4. Bridge your tokens</h1>
                  </>
                ) : collectionStatus === 'inactive' ? (
                  <>
                    <h1>4. Vote to approve the bridge</h1>
                    <p>Bridging must be approved by a majority vote.</p>
                    <p>1 token = 1 vote</p>
                    <h2 className="text-xl mt-3">Vote Status</h2>
                    <p className="text-2xl whitespace-nowrap mt-1 mb-3">
                      <span className="text-sapphire">
                        {collectionVoteStatus.data?.[0]?.toString() ?? 'unknown'}
                      </span>
                      &nbsp;<span>/</span>&nbsp;
                      <span>{collectionVoteStatus.data?.[1]?.toString() ?? 'unknown'}</span>
                    </p>
                    {(votingPower.data ?? 0) > 0 && (
                      <button className="action">
                        Cast&nbsp;{votingPower.data}&nbsp;
                        {`vote${votingPower.data! > 1 ? 's' : ''}`}
                      </button>
                    )}
                  </>
                ) : (
                  <>
                    <h1>Checking collection status...</h1>
                    <Loader color="#8ab1cf" loading={true} size={40} />
                  </>
                )}
              </div>
            )}
          </Connected>
        </div>
      </main>
      <footer className="py-8 bg-night text-center">
        <a href="https://enshrine.ai">
          <img width="50px" src="https://enshrine.ai/favicon.svg" className="mx-auto" />
          <span className="text-gray-200 text-lg">Enshrine Computing</span>
        </a>
      </footer>
    </>
  );
}
