#!/bin/bash

# Startup script to initialize and boot a peer instance.
#
# This script assumes the following files:
#  - `nethermind` binary is located in the filesystem root
#  - `genesis.json` file is located in the filesystem root (mandatory)
#  - `chain.rlp` file is located in the filesystem root (optional)
#  - `blocks` folder is located in the filesystem root (optional)
#  - `keys` folder is located in the filesystem root (optional)
#
# This script assumes the following environment variables:
#  - HIVE_BOOTNODE       enode URL of the remote bootstrap node
#  - HIVE_TESTNET        whether testnet nonces (2^20) are needed
#  - HIVE_NODETYPE       sync and pruning selector (archive, full, light)
#  - HIVE_FORK_HOMESTEAD block number of the DAO hard-fork transition
#  - HIVE_FORK_DAO_BLOCK block number of the DAO hard-fork transition
#  - HIVE_FORK_DAO_VOTE  whether the node support (or opposes) the DAO fork
#  - HIVE_MINER          address to credit with mining rewards (single thread)
#  - HIVE_MINER_EXTRA    extra-data field to set for newly minted blocks

# Immediately abort the script on any error encountered
set -e

# It doesn't make sense to dial out, use only a pre-set bootnode
# TODO - 
if [ "$HIVE_BOOTNODE" != "" ]; then
	export NETHERMIND_HIVECONFIG_BOOTNODE=$HIVE_BOOTNODE
fi

# Override any chain configs in the go-ethereum specific way
chainconfig="{}"
if [ "$HIVE_FORK_HOMESTEAD" != "" ]; then
	chainconfig=`echo $chainconfig | jq ". + {\"homesteadBlock\": $HIVE_FORK_HOMESTEAD}"`
fi
if [ "$HIVE_FORK_DAO_BLOCK" != "" ]; then
	chainconfig=`echo $chainconfig | jq ". + {\"daoForkBlock\": $HIVE_FORK_DAO_BLOCK}"`
fi
if [ "$HIVE_FORK_DAO_VOTE" == "0" ]; then
	chainconfig=`echo $chainconfig | jq ". + {\"daoForkSupport\": false}"`
fi
if [ "$HIVE_FORK_DAO_VOTE" == "1" ]; then
	chainconfig=`echo $chainconfig | jq ". + {\"daoForkSupport\": true}"`
fi

if [ "$HIVE_FORK_TANGERINE" != "" ]; then
	chainconfig=`echo $chainconfig | jq ". + {\"eip150Block\": $HIVE_FORK_TANGERINE}"`
fi
if [ "$HIVE_FORK_SPURIOUS" != "" ]; then
	chainconfig=`echo $chainconfig | jq ". + {\"eip158Block\": $HIVE_FORK_SPURIOUS}"`
	chainconfig=`echo $chainconfig | jq ". + {\"eip155Block\": $HIVE_FORK_SPURIOUS}"`
fi
if [ "$HIVE_FORK_BYZANTIUM" != "" ]; then
	chainconfig=`echo $chainconfig | jq ". + {\"byzantiumBlock\": $HIVE_FORK_BYZANTIUM}"`
fi
if [ "$HIVE_FORK_CONSTANTINOPLE" != "" ]; then
	chainconfig=`echo $chainconfig | jq ". + {\"constantinopleBlock\": $HIVE_FORK_CONSTANTINOPLE}"`
fi
genesis=`cat /genesis.json` && echo $genesis | jq ". + {\"config\": $chainconfig}" > /genesis.json



# Configure and set the chain definition for the node
configoverride=`jq -f /mapper.jq /genesis.json`
echo ".*$configoverride">/tempscript.jq
mergedconfig=`jq -f /tempscript.jq /chainspec/test.json`
echo $mergedconfig>/chainspec/test.json
echo "Chainspec:"
cat /chainspec/test.json
# Load any keys explicitly added to the node
#if [ -d /keys ]; then
#	export NETHERMIND_HIVECONFIG_KEYSDIR=keys
#fi


# Load the test chain if present
set +e
if [ -f /chain.rlp ]; then
	echo "Loading initial blockchain"
	cp /chain.rlp /chainspec/chain.rlp
	dotnet /ChainLoader/ChainLoader.dll --config /configs/test.cfg 2>&1
fi
set -e

echo "Running Nethermind..."
dotnet Nethermind.Runner.dll --log TRACE --config /configs/test.cfg  2>&1 | tee /log.txt
