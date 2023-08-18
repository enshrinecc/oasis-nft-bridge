import { useEffect, useMemo, useState } from 'react';
import { useAccount, useNetwork } from 'wagmi';
import Loader from 'react-spinners/GridLoader';

import { Bridger } from './components/Bridger';
import { CollectionChooser } from './components/CollectionChooser';
import { Connect } from './components/Connect';
import { Connected } from './components/Connected';
import { NetworkSwitcher } from './components/NetworkSwitcher';
import { Voter } from './components/Voter';

import {
  SupportedCollection,
  chainIsSupported,
  collectionIsSupported,
  getNetworkClassification,
} from './collections.js';
import { useVoteStatus } from './hooks/useVoteStatus.js';
import './index.css';

export function App() {
  const { address, isConnected } = useAccount();
  const { chain } = useNetwork();

  const [collection, setCollection] = useState<SupportedCollection | undefined>();

  const collectionVoteStatus = useVoteStatus(chain?.id, collection);

  useEffect(() => {
    if (!collectionIsSupported(collection, chain?.id)) setCollection(undefined);
  }, [chain]);

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
            src="/logo.svg"
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

            {chainIsSupported(chain?.id) && (
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
                    <Bridger collection={collection} />
                    <details className="mt-4">
                      <summary className="my-2 cursor-pointer text-gray-400">Tips</summary>
                      <ul className="text-left mx-auto max-w-prose list-disc px-4 text-gray-400">
                        <li className="my-3">
                          The Escrin Smart Worker that implements the bridge runs in a trusted
                          execution environment (TEE), which provides integrity and confidentiality.
                        </li>
                        <li className="my-3">
                          Bridging may take up to 30 minutes, but usually will taken about five.
                        </li>
                        <li className="my-3">
                          Once bridging has completed, your token will disappear from the list
                          above. Switch networks to see it again.
                        </li>
                        <li className="my-3">
                          If you have questions or comments, please reach out on{' '}
                          <a
                            className="underline"
                            href="https://enshrine.ai/discord"
                            target="_blank"
                          >
                            Discord
                          </a>
                          .
                        </li>
                        <li className="my-3">
                          The{' '}
                          <a
                            className="underline"
                            href="https://github.com/enshrinecc/oasis-nft-bridge"
                            target="_blank"
                          >
                            source code
                          </a>{' '}
                          for this app is freely available for reading and forking.
                        </li>
                      </ul>
                    </details>
                  </>
                ) : collectionStatus === 'inactive' ? (
                  <>
                    <h1>4. Vote to approve the bridge</h1>
                    <Voter collection={collection} />
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
          <img width="50px" src="/logo.svg" className="mx-auto" />
          <span className="text-gray-200 text-lg">Enshrine Computing</span>
        </a>
      </footer>
    </>
  );
}
