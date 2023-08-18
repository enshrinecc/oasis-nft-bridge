import { Chain, useNetwork, useSwitchNetwork } from 'wagmi';

export function NetworkSwitcher() {
  const { chains, error, switchNetwork } = useSwitchNetwork();

  const isMainnet = (ch: Chain) => ch.id === 0x5afe || ch.id == 0xa516;
  const isTestnet = (ch: Chain) => !isMainnet(ch);

  return (
    <div>
      {switchNetwork && (
        <>
          <NetworkButtons chains={chains.filter(isMainnet)} />
          <details className="mt-4" open={import.meta.env?.MODE === 'development'}>
            <summary className="my-2 cursor-pointer text-gray-400">Test Networks</summary>
            <NetworkButtons chains={chains.filter(isTestnet)} />
          </details>
        </>
      )}

      <div>{(error?.cause as any)?.code !== 4001 ? error?.message : ''}</div>
    </div>
  );
}

function NetworkButtons({ chains }: { chains: Chain[] }) {
  const { chain } = useNetwork();
  const { isLoading, pendingChainId, switchNetwork } = useSwitchNetwork();

  return (
    <div className="flex flex-col items-center mx-auto w-fit">
      {chains.map((ch) => (
        <button
          key={ch.id}
          disabled={ch.id === chain?.id}
          onClick={() => switchNetwork!(ch.id)}
          className={`w-full ${isLoading && ch.id === pendingChainId ? '!ring-rose-500' : ''}`}
        >
          {ch.name}
        </button>
      ))}
    </div>
  );
}
