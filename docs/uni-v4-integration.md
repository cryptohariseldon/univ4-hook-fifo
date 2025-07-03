# UNI-v4 Integration Guide

## Current Testing Approach

Our local tests use a simplified MockPoolManager because:

1. **Simplicity**: Easier to test hook logic without UNI-v4 complexity
2. **Speed**: Faster test execution without full AMM calculations
3. **Focus**: Tests focus on Continuum integration, not AMM mechanics

## Integrating with Real UNI-v4

### Prerequisites

1. **UNI-v4 Core Contracts**: Need to be deployed on the target network
2. **Hook Address Requirements**: UNI-v4 hooks must have specific address patterns
3. **Permissions**: Hook addresses encode permissions in their bits

### UNI-v4 Hook Address Requirements

UNI-v4 validates hook addresses based on permission flags encoded in the address:

```solidity
// Hook address format: 0x...FFFFFFFF
// Last 8 bytes encode permissions:
// - beforeSwap: 0x01
// - afterSwap: 0x02
// - beforeAddLiquidity: 0x04
// - afterAddLiquidity: 0x08
// etc.
```

Our hook needs:
- `beforeSwap` = true (to block direct swaps)
- `afterSwap` = true (to emit events)

### Deployment Strategy

#### 1. Using CREATE2 for Deterministic Addresses

```solidity
// Find a salt that produces an address with correct permission bits
function findValidHookAddress() external view returns (bytes32 salt, address hookAddress) {
    for (uint256 i = 0; i < 1000000; i++) {
        bytes32 testSalt = bytes32(i);
        address testAddress = getCreate2Address(testSalt);
        
        if (hasCorrectPermissions(testAddress)) {
            return (testSalt, testAddress);
        }
    }
    revert("No valid address found");
}
```

#### 2. Deploy on Testnet with Existing UNI-v4

**Base Sepolia** (Most Active):
- PoolManager: `0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829`
- PositionManager: `0x1a9062E4FAe8ab7580616B288e2BCBD10F8923B5`

**Sepolia**:
- Check latest addresses at: https://docs.uniswap.org/contracts/v4/deployments

### Integration Steps

1. **Deploy Hook with Correct Address**
```bash
# Find valid salt for CREATE2
forge script script/FindHookAddress.s.sol --rpc-url $SEPOLIA_RPC_URL

# Deploy with found salt
forge script script/DeployWithUniV4.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
```

2. **Create Pool with Hook**
```solidity
PoolKey memory key = PoolKey({
    currency0: Currency.wrap(USDC),
    currency1: Currency.wrap(WETH),
    fee: 3000,
    tickSpacing: 60,
    hooks: IHooks(CONTINUUM_HOOK_ADDRESS)
});

poolManager.initialize(key, INITIAL_SQRT_PRICE_X96);
```

3. **Add Liquidity**
```solidity
IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
    tickLower: -887220,
    tickUpper: 887220,
    liquidityDelta: 1000000000000000000, // 1e18
    salt: bytes32(0)
});

poolManager.modifyLiquidity(key, params, "");
```

4. **Execute Swaps via Continuum**
```solidity
// Users submit orders to Continuum
// Relayer executes ordered swaps
hook.executeTick(tickNumber, orderedSwaps, vdfProof, previousOutput);
```

### Testing on Testnet

1. **Base Sepolia** (Recommended):
   - Most active UNI-v4 testnet
   - Good faucets available
   - Active liquidity

2. **Sepolia**:
   - Ethereum testnet
   - May have less UNI-v4 activity

### Local Testing with Full UNI-v4

To deploy UNI-v4 locally:

```bash
# Clone UNI-v4
git clone https://github.com/Uniswap/v4-core
cd v4-core

# Install and compile
forge install
forge build

# Deploy locally
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

Then update our deployment script to use the local addresses.

## Differences from Mock

### Real UNI-v4 Features
1. **Concentrated Liquidity**: LPs can provide liquidity in specific price ranges
2. **Tick Management**: Price moves through discrete ticks
3. **Fee Tiers**: Multiple fee levels (0.05%, 0.3%, 1%)
4. **Flash Accounting**: Efficient multi-hop swaps
5. **Native ETH Support**: No WETH wrapping needed

### Additional Considerations
1. **Gas Costs**: Real UNI-v4 uses more gas than our mock
2. **Price Impact**: Actual slippage based on liquidity
3. **MEV**: More realistic MEV scenarios
4. **Liquidity**: Need to provide initial liquidity

## Recommended Approach

For development and testing:
1. **Phase 1**: Use MockPoolManager (current approach) ✅
2. **Phase 2**: Deploy on Base Sepolia with real UNI-v4
3. **Phase 3**: Mainnet deployment after audit

This staged approach allows us to:
- Quickly iterate on Continuum integration
- Test core functionality without UNI-v4 complexity
- Gradually add real AMM features
- Ensure security before mainnet