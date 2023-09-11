export const Abutment = [
  {
    "inputs": [],
    "name": "AcceptedTaskIdsNotSorted",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "InterfaceUnsupported",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "MismatchedTask",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "NotPresent",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "NotTaskHub",
    "type": "error"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "owner",
        "type": "address"
      }
    ],
    "name": "OwnableInvalidOwner",
    "type": "error"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "account",
        "type": "address"
      }
    ],
    "name": "OwnableUnauthorizedAccount",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "SubmisionTaskIdsNotSorted",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "TooSoon",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "UnknownQuantifier",
    "type": "error"
  },
  {
    "inputs": [],
    "name": "UnsupportedToken",
    "type": "error"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "previousOwner",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "newOwner",
        "type": "address"
      }
    ],
    "name": "OwnershipTransferStarted",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "previousOwner",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "newOwner",
        "type": "address"
      }
    ],
    "name": "OwnershipTransferred",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "address",
        "name": "to",
        "type": "address"
      }
    ],
    "name": "TaskHubChanged",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "components": [
          {
            "internalType": "contract IIdentityRegistry",
            "name": "registry",
            "type": "address"
          },
          {
            "internalType": "IdentityId",
            "name": "id",
            "type": "uint256"
          }
        ],
        "indexed": false,
        "internalType": "struct Abutment.TrustedIdentity",
        "name": "identity",
        "type": "tuple"
      }
    ],
    "name": "TrustedIdentityIncoming",
    "type": "event"
  },
  {
    "inputs": [],
    "name": "acceptOwnership",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256[]",
        "name": "taskIds",
        "type": "uint256[]"
      },
      {
        "internalType": "bytes",
        "name": "proof",
        "type": "bytes"
      },
      {
        "internalType": "bytes",
        "name": "report",
        "type": "bytes"
      }
    ],
    "name": "acceptTaskResults",
    "outputs": [
      {
        "components": [
          {
            "internalType": "enum ITaskAcceptor.Quantifier",
            "name": "quantifier",
            "type": "uint8"
          },
          {
            "internalType": "uint256[]",
            "name": "taskIds",
            "type": "uint256[]"
          }
        ],
        "internalType": "struct ITaskAcceptor.TaskIdSelector",
        "name": "sel",
        "type": "tuple"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "holder",
        "type": "address"
      },
      {
        "internalType": "contract IERC721",
        "name": "token",
        "type": "address"
      }
    ],
    "name": "getHeldTokens",
    "outputs": [
      {
        "internalType": "uint256[]",
        "name": "",
        "type": "uint256[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "contract IERC721",
        "name": "token",
        "type": "address"
      }
    ],
    "name": "getRemote",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getSupportedCollections",
    "outputs": [
      {
        "internalType": "contract IERC721[]",
        "name": "",
        "type": "address[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getTaskHub",
    "outputs": [
      {
        "internalType": "contract ITaskHub",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "contract IERC721",
        "name": "token",
        "type": "address"
      },
      {
        "internalType": "uint256[]",
        "name": "ids",
        "type": "uint256[]"
      }
    ],
    "name": "getTokenStatuses",
    "outputs": [
      {
        "components": [
          {
            "internalType": "address",
            "name": "owner",
            "type": "address"
          },
          {
            "internalType": "enum Abutment.Presence",
            "name": "presence",
            "type": "uint8"
          }
        ],
        "internalType": "struct Abutment.Token[]",
        "name": "",
        "type": "tuple[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "holder",
        "type": "address"
      },
      {
        "internalType": "contract IERC721",
        "name": "token",
        "type": "address"
      }
    ],
    "name": "getTokensByHolder",
    "outputs": [
      {
        "components": [
          {
            "internalType": "uint256",
            "name": "id",
            "type": "uint256"
          },
          {
            "internalType": "enum Abutment.Presence",
            "name": "presence",
            "type": "uint8"
          }
        ],
        "internalType": "struct Abutment.HeldToken[]",
        "name": "",
        "type": "tuple[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getTrustedIdentity",
    "outputs": [
      {
        "internalType": "contract IIdentityRegistry",
        "name": "",
        "type": "address"
      },
      {
        "internalType": "IdentityId",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "contract IERC721",
        "name": "token",
        "type": "address"
      }
    ],
    "name": "getVoteStatus",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "approvals",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "quorum",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "voter",
        "type": "address"
      },
      {
        "internalType": "contract IERC721",
        "name": "token",
        "type": "address"
      }
    ],
    "name": "getVotingTokens",
    "outputs": [
      {
        "internalType": "uint256[]",
        "name": "votingTokens",
        "type": "uint256[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "incomingTrustedIdentity",
    "outputs": [
      {
        "internalType": "contract IIdentityRegistry",
        "name": "registry",
        "type": "address"
      },
      {
        "internalType": "IdentityId",
        "name": "id",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "incomingTrustedIdentityActiveTime",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "from",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "tokenId",
        "type": "uint256"
      },
      {
        "internalType": "bytes",
        "name": "",
        "type": "bytes"
      }
    ],
    "name": "onERC721Received",
    "outputs": [
      {
        "internalType": "bytes4",
        "name": "",
        "type": "bytes4"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "owner",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "pendingOwner",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "renounceOwnership",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "components": [
          {
            "internalType": "contract IIdentityRegistry",
            "name": "registry",
            "type": "address"
          },
          {
            "internalType": "IdentityId",
            "name": "id",
            "type": "uint256"
          }
        ],
        "internalType": "struct Abutment.TrustedIdentity",
        "name": "identity",
        "type": "tuple"
      }
    ],
    "name": "setTrustedIdentity",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "bytes4",
        "name": "interfaceId",
        "type": "bytes4"
      }
    ],
    "name": "supportsInterface",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "newOwner",
        "type": "address"
      }
    ],
    "name": "transferOwnership",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "trustedIdentityUpdateDelay",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "contract IERC721",
        "name": "token",
        "type": "address"
      },
      {
        "internalType": "uint256[]",
        "name": "tokenIds",
        "type": "uint256[]"
      }
    ],
    "name": "vote",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
] as const;