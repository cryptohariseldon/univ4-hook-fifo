# Sepolia/Base Sepolia Deployment Guide

This guide covers deploying the Continuum UNI-v4 integration on testnet with real UNI-v4 contracts.

## Prerequisites

1. **Testnet ETH**: Get testnet ETH from faucets
   - Base Sepolia: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
   - Sepolia: https://sepoliafaucet.com/

2. **Environment Setup**:
```bash
# Create .env file
cat > .env << EOF
PRIVATE_KEY=your_private_key_here
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your_key
EOF
```

## Deployment Steps

### 1. Deploy Continuum Contracts

Deploy the Continuum verifier and hook with proper permissions:

```bash
# For Base Sepolia (recommended - has active UNI-v4)
forge script script/DeploySepoliaV4.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast

# For Ethereum Sepolia
forge script script/DeploySepoliaV4.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
```

This script will:
- Deploy the Continuum Verifier
- Find a valid hook address using CREATE2
- Deploy the hook with correct permission bits
- Save deployment addresses

### 2. Initialize Pool

Create a UNI-v4 pool with the Continuum hook:

```bash
# Set the hook address from deployment
export HOOK_ADDRESS=0x... # From deployment output

# Initialize pool
forge script script/InitializePoolV4.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
```

This will:
- Create a USDC/WETH pool with 0.3% fee
- Attach the Continuum hook
- Add initial liquidity

### 3. Test Swap Execution

Execute swaps through Continuum:

```bash
# Set contract addresses
export VERIFIER_ADDRESS=0x... # From deployment
export HOOK_ADDRESS=0x... # From deployment

# Run test swaps
forge script script/TestSwapV4.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
```

## Addresses

### Base Sepolia
- **Pool Manager**: `0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829`
- **Position Manager**: `0x1a9062E4FAe8ab7580616B288e2BCBD10F8923B5`
- **USDC**: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`
- **WETH**: `0x4200000000000000000000000000000000000006`

### Hook Address Requirements

UNI-v4 validates hook addresses based on permission flags encoded in the address bits:

```
Address: 0x...FFFFFFFF
Last bits encode permissions:
- beforeSwap: 0x80 (bit 7)
- afterSwap: 0x40 (bit 6)
```

Our hook needs both flags, so the address must have bits 6 and 7 set.

## Integration Flow

1. **Users Submit Orders**: Users sign swap orders and submit to Continuum
2. **Continuum Orders**: Continuum sequences orders using VDF
3. **Relayer Executes**: Authorized relayer executes ordered swaps onchain
4. **Hook Validates**: Hook ensures all swaps go through Continuum

## Gas Costs (Estimated)

- Hook deployment: ~2M gas
- Pool initialization: ~500k gas
- Single swap execution: ~200k gas
- Batch of 10 swaps: ~1M gas (~100k per swap)

## Troubleshooting

### "Hook address not valid"
The hook address must have correct permission bits. The deployment script automatically finds a valid address using CREATE2.

### "Pool not initialized"
Ensure the pool was created with the correct parameters and the hook address matches.

### "Unauthorized relayer"
Only authorized relayers can execute ticks. Add relayer authorization:
```solidity
hook.authorizeRelayer(relayerAddress, true);
```

## Next Steps

1. **Production Deployment**:
   - Audit smart contracts
   - Deploy on mainnet
   - Set up relayer infrastructure

2. **Continuum Integration**:
   - Connect to real Continuum sequencer
   - Implement proper VDF verification
   - Set up monitoring

3. **User Interface**:
   - Build SDK for order submission
   - Create web interface
   - Add wallet integrations