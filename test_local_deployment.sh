#!/bin/bash

echo "=== Continuum UNI-v4 Hook Local Testing Script ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Function to check if a command succeeded
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1 successful${NC}"
    else
        echo -e "${RED}✗ $1 failed${NC}"
        exit 1
    fi
}

# Check if Anvil is running
echo "Checking if local node is running..."
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Local node not running. Please run ./start_local_node.sh first${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Local node is running${NC}"
echo ""

# Deploy contracts
echo "Deploying contracts to local network..."
DEPLOY_OUTPUT=$(forge script script/LocalDemo.s.sol --rpc-url http://localhost:8545 --broadcast 2>&1)

if [[ $DEPLOY_OUTPUT == *"error"* ]]; then
    echo -e "${RED}✗ Deployment failed${NC}"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

# Extract addresses from deployment output
HOOK_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -A1 "Hook:" | tail -1 | awk '{print $1}')
VERIFIER_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -A1 "Verifier:" | tail -1 | awk '{print $1}')

if [ -z "$HOOK_ADDRESS" ] || [ -z "$VERIFIER_ADDRESS" ]; then
    echo -e "${YELLOW}Could not extract contract addresses. Running deployment...${NC}"
    forge script script/LocalDemo.s.sol --rpc-url http://localhost:8545 --broadcast -vvv
    exit 1
fi

echo -e "${GREEN}✓ Contracts deployed${NC}"
echo "  Hook: $HOOK_ADDRESS"
echo "  Verifier: $VERIFIER_ADDRESS"
echo ""

# Update relayer .env file
echo "Updating relayer configuration..."
cat > relayer/.env << EOF
# Relayer Configuration
PORT=8091
RPC_URL=http://localhost:8545
RELAYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Contract addresses
HOOK_ADDRESS=$HOOK_ADDRESS
VERIFIER_ADDRESS=$VERIFIER_ADDRESS

# Optional: Log level
LOG_LEVEL=info
EOF

check_success "Relayer configuration updated"
echo ""

# Test contract functionality
echo "Testing contract functionality..."
forge test --match-test testFullSwapFlow -vv
check_success "Contract tests"
echo ""

# Summary
echo "=== Setup Complete ==="
echo ""
echo "Local deployment successful! You can now:"
echo ""
echo "1. Start the relayer:"
echo "   ${YELLOW}./start_relayer.sh${NC}"
echo ""
echo "2. Submit test orders to the relayer:"
echo "   ${YELLOW}curl -X POST http://localhost:8091/api/submit-order \\
     -H \"Content-Type: application/json\" \\
     -d '{
       \"user\": \"0x70997970C51812dc3A010C7d01b50e0d17dc79C8\",
       \"poolKey\": {
         \"currency0\": \"0x5FbDB2315678afecb367f032d93F642f64180aa3\",
         \"currency1\": \"0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512\",
         \"fee\": 3000,
         \"tickSpacing\": 60,
         \"hooks\": \"$HOOK_ADDRESS\"
       },
       \"params\": {
         \"zeroForOne\": true,
         \"amountSpecified\": \"1000000000000000000\",
         \"sqrtPriceLimitX96\": \"0\"
       },
       \"deadline\": 9999999999
     }'${NC}"
echo ""
echo "3. Check relayer status:"
echo "   ${YELLOW}curl http://localhost:8091/api/status${NC}"
echo ""