# Continuum Relayer Service

The relayer service is responsible for collecting user swap orders, batching them, and submitting them to the Continuum-enabled UNI-v4 pools with proper VDF proofs.

## Architecture

The relayer acts as the bridge between users and the Continuum sequencing network:

```
Users → Relayer API → Order Queue → VDF Verification → Hook Contract → UNI-v4 Pool
```

## Features

- **REST API** for order submission and status queries
- **Order batching** with configurable batch size (up to 100 swaps per tick)
- **10ms tick processing** for ultra-fast order execution
- **VDF proof generation** (mock for demo, real VDF in production)
- **Automatic retry** with exponential backoff
- **Order expiration** handling
- **Real-time status monitoring**

## API Endpoints

### Submit Order
```
POST /api/submit-order
Content-Type: application/json

{
  "user": "0x...",
  "poolKey": {
    "currency0": "0x...",
    "currency1": "0x...",
    "fee": 3000,
    "tickSpacing": 60,
    "hooks": "0x..."
  },
  "params": {
    "zeroForOne": true,
    "amountSpecified": "1000000000000000000",
    "sqrtPriceLimitX96": "0"
  },
  "deadline": 1234567890
}
```

### Get Order Status
```
GET /api/order/:orderId
```

### Get Executed Tick
```
GET /api/tick/:tickNumber
```

### Relayer Status
```
GET /api/status
```

## Authentication

The relayer uses an on-chain authorization system:

1. **Deployment**: The deployer is automatically authorized as a relayer
2. **Authorization**: Additional relayers can be authorized via `authorizeRelayer(address, bool)`
3. **Verification**: The `ContinuumSwapHook` contract checks `authorizedRelayers[msg.sender]`

Only authorized relayers can submit tick executions to prevent spam and ensure system integrity.

## Configuration

Environment variables (`.env` file):

```bash
# Server
PORT=8091
RPC_URL=http://localhost:8545

# Relayer wallet (must be authorized on-chain)
RELAYER_PRIVATE_KEY=0x...

# Contract addresses (set after deployment)
HOOK_ADDRESS=0x...
VERIFIER_ADDRESS=0x...
```

## Running the Relayer

### Quick Start
```bash
# From the root directory
./start_relayer.sh
```

### Manual Start
```bash
cd relayer
npm install
npm start
```

### Development Mode
```bash
cd relayer
npm run dev  # Uses nodemon for auto-restart
```

## How It Works

1. **Order Collection**: Users submit swap orders via the REST API
2. **Queue Management**: Orders are queued and validated
3. **Batch Formation**: Every 10ms, the relayer collects up to 100 pending orders
4. **VDF Proof**: A VDF proof is generated for the batch (mock in demo)
5. **On-chain Execution**: The relayer calls `executeTick()` on the hook contract
6. **Settlement**: The hook executes swaps in the exact order specified

## Security Considerations

1. **Order Signing**: In production, orders should be signed by users
2. **Rate Limiting**: Implement rate limiting to prevent spam
3. **Monitoring**: Track gas usage and failed transactions
4. **Key Management**: Use secure key storage (HSM, KMS) in production
5. **Access Control**: Regularly audit authorized relayers

## Monitoring

The relayer logs all operations to:
- Console output (stdout)
- Log file (`relayer.log`)

Monitor for:
- Failed transactions
- High gas usage
- Order queue size
- Processing delays

## Testing

```bash
# Run tests
cd relayer
npm test

# Test order submission
curl -X POST http://localhost:8091/api/submit-order \
  -H "Content-Type: application/json" \
  -d '{
    "user": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "poolKey": {
      "currency0": "0x5FbDB2315678afecb367f032d93F642f64180aa3",
      "currency1": "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
      "fee": 3000,
      "tickSpacing": 60,
      "hooks": "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
    },
    "params": {
      "zeroForOne": true,
      "amountSpecified": "1000000000000000000",
      "sqrtPriceLimitX96": "0"
    },
    "deadline": 9999999999
  }'

# Check status
curl http://localhost:8091/api/status
```

## Production Deployment

For production:

1. Use proper VDF verification with actual Continuum network
2. Implement order signing and verification
3. Add monitoring and alerting (Prometheus, Grafana)
4. Use secure key management
5. Implement rate limiting and DDoS protection
6. Set up multiple relayers for redundancy
7. Use WebSocket for real-time updates