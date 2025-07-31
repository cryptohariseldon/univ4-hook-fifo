#!/bin/bash

echo "Starting Anvil local Ethereum node..."
echo "===================================="
echo ""
echo "Network Details:"
echo "- RPC URL: http://localhost:8545"
echo "- Chain ID: 31337"
echo "- Gas Price: 0"
echo "- Block Time: Instant"
echo ""
echo "Test Accounts (10 ETH each):"
echo "- Account 0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
echo "  Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
echo ""
echo "Press Ctrl+C to stop"
echo "===================================="
echo ""

# Start Anvil with deterministic addresses and accounts
anvil \
  --host 0.0.0.0 \
  --accounts 10 \
  --balance 10000 \
  --mnemonic "test test test test test test test test test test test junk" \
  --port 8545