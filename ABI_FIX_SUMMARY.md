# Relayer ABI Issues - Fixed

## Issues Found and Fixed:

1. **ABI Path Issue**: Fixed the path to correctly load ABI files from `../../out/`

2. **Variable Scope Issue**: Fixed `tx` variable scope in TickExecutor

3. **Tick Already Executed**: Updated relayer to start from tick 2 since tick 1 was used in demo

4. **Transaction Encoding**: Modified to send transaction directly with encoded data using wallet.sendTransaction()

## Current Status:

The relayer now:
- ✅ Properly loads contract ABIs
- ✅ Correctly encodes function calls (1930 bytes for executeTick)
- ✅ Submits transactions with proper data
- ⚠️ Transactions still reverting due to VDF chain verification

## Remaining Issue:

The contract is reverting with error `!T%(` which appears to be related to VDF proof verification. The issue is likely:
1. The previous output chain continuity check
2. The VDF proof validation itself

## How the Fixed Relayer Works:

1. **Order Submission**: POST to `/api/submit-order`
2. **Batching**: Orders collected every 10ms
3. **VDF Proof**: Mock proof generated with proper encoding
4. **Transaction**: Sent directly with encoded data
5. **Verification**: Contract validates VDF proof and chain continuity

## Test Commands:

```bash
# Start relayer
./start_relayer.sh

# Submit order
curl -X POST http://localhost:8091/api/submit-order \
  -H "Content-Type: application/json" \
  -d '{
    "user": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "poolKey": {
      "currency0": "0x5FbDB2315678afecb367f032d93F642f64180aa3",
      "currency1": "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
      "fee": 3000,
      "tickSpacing": 60,
      "hooks": "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9"
    },
    "params": {
      "zeroForOne": true,
      "amountSpecified": "1000000000000000000",
      "sqrtPriceLimitX96": "0"
    },
    "deadline": 9999999999
  }'
```

The core ABI encoding issues have been resolved. The remaining challenge is ensuring the VDF proof chain validation passes in the smart contract.