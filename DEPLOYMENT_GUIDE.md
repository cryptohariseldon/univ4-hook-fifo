# Testnet Deployment Guide

## Current Status

The contracts are ready for deployment. We have:
- ✅ Updated all contracts to use UNI-v4 core
- ✅ Created deployment scripts
- ✅ All tests passing (28/28)

## Deployment Wallet

```
Address: 0x7e718896781c0727e01D4ab5991374667ccC4dD6
Private Key: (in .env file)
```

## Getting Testnet ETH

### Option 1: Base Sepolia (Recommended)
Base Sepolia has active UNI-v4 deployment and is the best choice.

1. **Coinbase Faucet** (0.1 ETH per day):
   - Visit: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
   - Enter wallet address: `0x7e718896781c0727e01D4ab5991374667ccC4dD6`
   - Complete captcha and request funds

2. **Alternative Faucets**:
   - Alchemy: https://basefaucet.com/
   - QuickNode: https://faucet.quicknode.com/base/sepolia

### Option 2: Ethereum Sepolia
1. **Sepolia Faucet**:
   - Visit: https://sepoliafaucet.com/
   - Enter wallet address and request funds

## Deployment Steps

### 1. Deploy Contracts

Once you have testnet ETH, deploy the contracts:

```bash
# For Base Sepolia (recommended)
forge script script/DeploySepoliaV4Simple.s.sol \
  --rpc-url https://sepolia.base.org \
  --broadcast \
  --verify

# For Ethereum Sepolia
forge script script/DeploySepoliaV4Simple.s.sol \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY \
  --broadcast \
  --verify
```

### 2. Initialize Pool

After deployment, create a pool with the hook:

```bash
# Set the deployed addresses
export VERIFIER_ADDRESS=0x... # From deployment output
export HOOK_ADDRESS=0x... # From deployment output

# Initialize pool
forge script script/InitializePoolV4.s.sol \
  --rpc-url https://sepolia.base.org \
  --broadcast
```

### 3. Test Swaps

Execute test swaps through Continuum:

```bash
forge script script/TestSwapV4.s.sol \
  --rpc-url https://sepolia.base.org \
  --broadcast
```

## Expected Results

### Deployment Output
```
=== Deploying Continuum Hook for UNI-v4 ===
Network: Base Sepolia
Deployer: 0x7e718896781c0727e01D4ab5991374667ccC4dD6

1. Deploying Continuum Verifier...
   Verifier deployed at: 0x...

2. Deploying Continuum Hook...
   Hook deployed at: 0x...

3. Checking hook configuration...
   Has beforeSwap permission: true/false
   Has afterSwap permission: true/false
```

### Gas Costs (Estimated)
- Verifier deployment: ~500k gas
- Hook deployment: ~2M gas
- Pool initialization: ~300k gas
- Single swap: ~200k gas

## Verification

After deployment, verify contracts on Etherscan:

```bash
# Verify Verifier
forge verify-contract VERIFIER_ADDRESS ContinuumVerifier \
  --chain base-sepolia

# Verify Hook
forge verify-contract HOOK_ADDRESS ContinuumSwapHook \
  --constructor-args $(cast abi-encode "constructor(address,address)" POOL_MANAGER_ADDRESS VERIFIER_ADDRESS) \
  --chain base-sepolia
```

## Addresses

### Base Sepolia
- **Pool Manager**: `0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829`
- **USDC**: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`
- **WETH**: `0x4200000000000000000000000000000000000006`

## Alternative: Use Your Own RPC

If you have access to Infura, Alchemy, or another RPC provider:

1. Update `.env`:
```bash
BASE_SEPOLIA_RPC_URL=https://base-sepolia.infura.io/v3/YOUR_PROJECT_ID
```

2. Deploy:
```bash
forge script script/DeploySepoliaV4Simple.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast
```

## Next Steps

After successful deployment:
1. Share the deployed contract addresses
2. Test swap execution through Continuum
3. Monitor gas usage and performance
4. Prepare for mainnet deployment