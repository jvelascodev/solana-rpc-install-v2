#!/bin/bash
# ==================================================================
# Solana Pruned RPC Node - Mainnet Follower
# ==================================================================
# Configuration:
# - No Voting (Mainnet Follower)
# - Pruned Ledger (80GB limit)
# - No Accounts Index (Lightweight)
# - No Store Ledger
# - Full RPC API (with limitations due to no index)
# - Dynamic Port Range: 8000-8010
# ==================================================================

export RUST_LOG=warn
export RUST_BACKTRACE=1

# Auto-detect Public IP for gossip
PUBLIC_IP=$(curl -s ifconfig.me || curl -s icanhazip.com)
if [[ -z "$PUBLIC_IP" ]]; then
    echo "ERROR: Could not detect public IP. Please set it manually."
    exit 1
fi

echo "Starting Solana Pruned RPC Node..."
echo "Public IP: $PUBLIC_IP"
echo "Ledger Limit: 80,000,000 (~80GB)"

exec solana-validator \
 --entrypoint entrypoint.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint4.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint5.mainnet-beta.solana.com:8001 \
 --known-validator Certusm1sa411sMpV9FPqU5dXAYhmmhygvxJ23S6hJ24 \
 --known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
 --known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
 --known-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S \
 --known-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ \
 --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
 --no-voting \
 --disable-deploy-os-check \
 --dynamic-port-range 8000-8010 \
 --gossip-port 8001 \
 --gossip-host "$PUBLIC_IP" \
 --ledger /root/sol/ledger \
 --limit-ledger-size 80000000 \
 --accounts /root/sol/accounts \
 --snapshots /root/sol/snapshot \
 --rpc-port 8899 \
 --rpc-bind-address 0.0.0.0 \
 --full-rpc-api \
 --private-rpc \
 --no-snapshot-fetch \
 --no-genesis-fetch \
 --no-os-network-limits-test \
 --no-accounts-db-index \
 --no-store-ledger \
 --wal-recovery-mode skip_any_corrupted_record \
 --identity /root/sol/bin/validator-keypair.json \
 --log /root/solana-rpc.log \
 --geyser-plugin-config /root/sol/bin/yellowstone-config.json
