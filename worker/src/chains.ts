import { Chain } from 'viem';
import { localhost } from 'viem/chains';

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

export default function (name: string): Chain {
  if (name === 'local') return { ...localhost, id: 31337 };
  if (name === 'sapphire-testnet') return sapphireTestnet;
  if (name === 'sapphire-mainnet') return sapphire;
  if (name === 'emerald-testnet') return emeraldTestnet;
  if (name === 'emerald-mainnet') return emerald;
  throw new Error(`unrecognized chain: ${name}`);
}
