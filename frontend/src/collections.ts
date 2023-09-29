import { Address } from 'wagmi';

const abutments: Partial<Record<SupportedChain, Address>> = {
  1337: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
  31337: '0x5FC8d32690cc91D4c39d9d3abcBD16989F875707',
  0x5aff: '0xCf05273778a80416098eC9219F40caaEe9b27A36',
  0x5afe: '0x9ff55e0931174909E723B2CEc591b638cF2aaCC8',
  0xa515: '0x63c13Ee9BecC8f35dC034F026Ae8d18A4D1E7f0E',
  0xa516: '0x031B36a65f15239b2EbE481218Cd7e076a6f16f7',
};

const collections: Record<SupportedCollection, Collection> = {
  'ai-rose': {
    name: 'AI Rose',
    chains: {
      0xa516: '0x0f4c5A429166608f9225E094F7E66B0bF68a53B9',
      0x5afe: '0x24E0E56A214Bd3e8e546Ba04505eF3E9E5EF216a',
    },
  },
  test: {
    name: 'Test Token',
    chains: {
      1337: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
      31337: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    },
  },
  mock: {
    name: 'Mock Token',
    chains: {
      0x5aff: '0x33340BdC56E220741846684A93E7E08D4495Dca6',
      0xa515: '0x0534868ef68D4312Ae1F10ba6b0b621F2308d227',
    },
  },
};

export type SupportedCollection = 'test' | 'ai-rose' | 'mock';
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

export function getCollectionExplorerURL(
  id: string,
  chainId: number | undefined,
): string | undefined {
  const addr = getCollectionAddr(id, chainId);
  if (!addr) return;
  const network = chainId === 0x5afe || chainId === 0xa516 ? 'mainnet' : ' testnet';
  const classification = getNetworkClassification(chainId as SupportedChain);
  return `https://explorer.oasis.io/${network}/${classification}/address/${addr}`;
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
