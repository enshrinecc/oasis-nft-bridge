import { configureChains, createConfig } from 'wagmi';
import { Chain, foundry, localhost } from 'wagmi/chains';
import { InjectedConnector } from 'wagmi/connectors/injected';

import { publicProvider } from 'wagmi/providers/public';

import { emerald, sapphire, emeraldTestnet, sapphireTestnet } from './chains.js';

const jsonrpc8456 = {
  http: ['http://127.0.0.1:8546'],
  webSocket: ['ws://127.0.0.1:8546'],
};
const localhost8546 = {
  ...localhost,
  rpcUrls: {
    default: jsonrpc8456,
    public: jsonrpc8456,
  },
} as const satisfies Chain;

const { chains, publicClient, webSocketPublicClient } = configureChains(
  [
    emerald,
    sapphire,
    emeraldTestnet,
    sapphireTestnet,
    ...(import.meta.env?.MODE === 'development'
      ? [
          { ...foundry, name: 'Local Sapphire' },
          { ...localhost8546, name: 'Local Emerald' },
        ]
      : []),
  ],
  [publicProvider()],
);

export const config = createConfig({
  autoConnect: true,
  connectors: [
    new InjectedConnector({
      chains,
      options: {
        shimDisconnect: true,
      },
    }),
  ],
  publicClient,
  webSocketPublicClient,
});
