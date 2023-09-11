import { Chain } from 'viem';
import { foundry, localhost } from 'viem/chains';

export const sapphire = {
  id: 0x5afe,
  name: 'Oasis Sapphire',
  network: 'sapphire',
  nativeCurrency: {
    decimals: 18,
    name: 'Oasis ROSE',
    symbol: 'ROSE',
  },
  rpcUrls: {
    default: { http: ['https://sapphire.oasis.io'] },
    public: { http: ['https://sapphire.oasis.io'] },
  },
  blockExplorers: {
    default: { name: 'Oasis Explorer', url: 'https://explorer.oasis.io/mainnet/sapphire' },
  },
  contracts: {
    multicall3: {
      address: '0xcA11bde05977b3631167028862bE2a173976CA11',
      blockCreated: 734531,
    },
  },
} as Chain;

export const emerald = {
  id: 0xa516,
  name: 'Oasis Emerald',
  network: 'emerald',
  nativeCurrency: {
    decimals: 18,
    name: 'Oasis ROSE',
    symbol: 'ROSE',
  },
  rpcUrls: {
    default: { http: ['https://emerald.oasis.dev'] },
    public: { http: ['https://emerald.oasis.dev'] },
  },
  blockExplorers: {
    default: { name: 'Oasis Explorer', url: 'https://explorer.oasis.io/mainnet/emerald' },
  },
} as Chain;

export const sapphireTestnet = {
  id: 0x5aff,
  name: 'Oasis Sapphire Testnet',
  network: 'sapphire-testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'TEST',
    symbol: 'TEST',
  },
  rpcUrls: {
    default: { http: ['https://testnet.sapphire.oasis.dev'] },
    public: { http: ['https://testnet.sapphire.oasis.dev'] },
  },
  blockExplorers: {
    default: { name: 'Oasis Explorer', url: 'https://explorer.oasis.io/testnet/sapphire' },
  },
} as Chain;

export const emeraldTestnet = {
  id: 0xa516,
  name: 'Oasis Emerald Testnet',
  network: 'emerald-testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'TEST',
    symbol: 'TEST',
  },
  rpcUrls: {
    default: { http: ['https://testnet.emerald.oasis.dev'] },
    public: { http: ['https://testnet.emerald.oasis.dev'] },
  },
  blockExplorers: {
    default: { name: 'Oasis Explorer', url: 'https://explorer.oasis.io/testnet/emerald' },
  },
} as Chain;

export function getChain(chainId: number, rpcUrl?: string): Chain {
  if (rpcUrl) {
    return {
      id: chainId,
      name: 'Custom Network',
      network: 'custom',
      nativeCurrency: { decimals: 18, name: '', symbol: '' },
      rpcUrls: {
        default: { http: [rpcUrl] },
        public: { http: [rpcUrl] },
      },
    };
  }
  if (chainId === 0x5afe) return sapphire;
  if (chainId === 0x5aff) return sapphireTestnet;
  if (chainId === 31337) return foundry;
  if (chainId === 1337) return localhost;
  throw new Error(`the chain with id ${chainId} is unrecognized, so \`rpcUrl\` is required`);
}
