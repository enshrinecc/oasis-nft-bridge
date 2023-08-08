export const AbutmentAbi = [
  { inputs: [], name: 'AcceptedTaskIdsNotSorted', type: 'error' },
  { inputs: [], name: 'MismatchedTask', type: 'error' },
  { inputs: [], name: 'NotPresent', type: 'error' },
  { inputs: [], name: 'NotTaskAcceptor', type: 'error' },
  { inputs: [], name: 'NotTaskHub', type: 'error' },
  { inputs: [], name: 'SubmisionTaskIdsNotSorted', type: 'error' },
  { inputs: [], name: 'TooSoon', type: 'error' },
  { inputs: [], name: 'UnknownQuantifier', type: 'error' },
  { inputs: [], name: 'UnsupportedToken', type: 'error' },
  {
    anonymous: false,
    inputs: [
      { indexed: false, internalType: 'contract ITaskAcceptorV1', name: 'to', type: 'address' },
    ],
    name: 'TaskAcceptorChanged',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: 'contract ITaskAcceptorV1',
        name: 'incomingTaskAcceptor',
        type: 'address',
      },
      { indexed: false, internalType: 'uint256', name: 'activeTime', type: 'uint256' },
    ],
    name: 'TaskAcceptorIncoming',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [{ indexed: false, internalType: 'address', name: 'to', type: 'address' }],
    name: 'TaskHubChanged',
    type: 'event',
  },
  {
    inputs: [
      { internalType: 'uint256[]', name: '_taskIds', type: 'uint256[]' },
      { internalType: 'bytes', name: '_proof', type: 'bytes' },
      { internalType: 'bytes', name: '_report', type: 'bytes' },
    ],
    name: 'acceptTaskResults',
    outputs: [
      {
        components: [
          { internalType: 'enum ITaskAcceptorV1.Quantifier', name: 'quantifier', type: 'uint8' },
          { internalType: 'uint256[]', name: 'taskIds', type: 'uint256[]' },
        ],
        internalType: 'struct ITaskAcceptorV1.TaskIdSelector',
        name: 'sel',
        type: 'tuple',
      },
    ],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'contract IERC721', name: '_token', type: 'address' }],
    name: 'getAbutmentTokens',
    outputs: [{ internalType: 'uint256[]', name: '', type: 'uint256[]' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'contract IERC721', name: '_token', type: 'address' }],
    name: 'getRemote',
    outputs: [{ internalType: 'address', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getSupportedCollections',
    outputs: [{ internalType: 'contract IERC721[]', name: '', type: 'address[]' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getTaskAcceptor',
    outputs: [{ internalType: 'contract ITaskAcceptorV1', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'contract IERC721', name: '_token', type: 'address' },
      { internalType: 'uint256[]', name: '_ids', type: 'uint256[]' },
    ],
    name: 'getTokenStatuses',
    outputs: [
      {
        components: [
          { internalType: 'address', name: 'owner', type: 'address' },
          { internalType: 'enum Abutment.Presence', name: 'presence', type: 'uint8' },
        ],
        internalType: 'struct Abutment.Token[]',
        name: '',
        type: 'tuple[]',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'contract IERC721', name: '_token', type: 'address' }],
    name: 'getVoteStatus',
    outputs: [
      { internalType: 'uint256', name: 'approvals', type: 'uint256' },
      { internalType: 'uint256', name: 'quorum', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: '', type: 'address' },
      { internalType: 'address', name: '_from', type: 'address' },
      { internalType: 'uint256', name: '_tokenId', type: 'uint256' },
      { internalType: 'bytes', name: '', type: 'bytes' },
    ],
    name: 'onERC721Received',
    outputs: [{ internalType: 'bytes4', name: '', type: 'bytes4' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'taskHub',
    outputs: [{ internalType: 'contract ITaskHubV1', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'contract IERC721', name: '_token', type: 'address' },
      { internalType: 'uint256[]', name: '_tokenIds', type: 'uint256[]' },
    ],
    name: 'vote',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const;
