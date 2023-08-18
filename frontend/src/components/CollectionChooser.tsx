import { useMemo } from 'react';
import { useNetwork } from 'wagmi';

import { SupportedCollection, getCollections } from '../collections.js';

export function CollectionChooser({
  collection,
  setCollection,
}: {
  collection?: string;
  setCollection: (collection: SupportedCollection) => void;
}) {
  const { chain } = useNetwork();
  const collections = useMemo(
    () => (chain?.id ? Object.entries(getCollections(chain.id)) : []),
    [chain],
  );

  if (collections.length === 0)
    return (
      <p className="mt-8 mb-4 max-w-prose">
        There are no collections available to be bridged on this network.
      </p>
    );

  return (
    <ul>
      {collections.map(([id, coll]) => (
        <li key={id}>
          <button
            disabled={collection === id}
            onClick={() => setCollection(id as SupportedCollection)}
          >
            {coll.name}
          </button>
        </li>
      ))}
    </ul>
  );
}
