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
  return (
    <ul>
      {Object.entries(chain?.id ? getCollections(chain.id) : {}).map(([id, coll]) => (
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
