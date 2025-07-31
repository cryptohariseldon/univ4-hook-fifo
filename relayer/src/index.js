const express = require('express');
const { ethers } = require('ethers');
const cors = require('cors');
const winston = require('winston');
const cron = require('node-cron');
require('dotenv').config();

const OrderQueue = require('./services/OrderQueue');
const TickExecutor = require('./services/TickExecutor');
const VDFVerifier = require('./services/VDFVerifier');
const config = require('./config');

// Setup logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'relayer.log' })
  ]
});

// Initialize services
const app = express();
app.use(cors());
app.use(express.json());

// Connect to Ethereum
let provider;
let wallet;
let contracts = {};

async function initialize() {
  try {
    // Setup provider
    const rpcUrl = process.env.RPC_URL || 'http://localhost:8545';
    provider = new ethers.JsonRpcProvider(rpcUrl);
    
    // Setup wallet
    const privateKey = process.env.RELAYER_PRIVATE_KEY || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
    wallet = new ethers.Wallet(privateKey, provider);
    
    logger.info(`Relayer initialized with address: ${wallet.address}`);
    
    // Load contract ABIs and addresses
    const hookAddress = process.env.HOOK_ADDRESS;
    const verifierAddress = process.env.VERIFIER_ADDRESS;
    
    if (hookAddress && verifierAddress) {
      const hookABI = require('../../out/ContinuumSwapHook.sol/ContinuumSwapHook.json').abi;
      const verifierABI = require('../../out/ContinuumVerifier.sol/ContinuumVerifier.json').abi;
      
      contracts.hook = new ethers.Contract(hookAddress, hookABI, wallet);
      contracts.verifier = new ethers.Contract(verifierAddress, verifierABI, wallet);
      
      logger.info(`Connected to contracts - Hook: ${hookAddress}, Verifier: ${verifierAddress}`);
    } else {
      logger.warn('Contract addresses not configured. Running in mock mode.');
    }
    
    // Initialize services
    const orderQueue = new OrderQueue();
    const vdfVerifier = new VDFVerifier();
    const tickExecutor = new TickExecutor(contracts, wallet, logger);
    
    // API endpoints
    app.post('/api/submit-order', async (req, res) => {
      try {
        const order = req.body;
        
        // Validate order
        if (!order.user || !order.poolKey || !order.params) {
          return res.status(400).json({ error: 'Invalid order format' });
        }
        
        // Add to queue
        const orderId = await orderQueue.addOrder(order);
        
        logger.info(`Order received: ${orderId}`);
        res.json({ success: true, orderId });
      } catch (error) {
        logger.error('Error submitting order:', error);
        res.status(500).json({ error: error.message });
      }
    });
    
    app.get('/api/order/:orderId', async (req, res) => {
      try {
        const order = await orderQueue.getOrder(req.params.orderId);
        if (!order) {
          return res.status(404).json({ error: 'Order not found' });
        }
        res.json(order);
      } catch (error) {
        logger.error('Error fetching order:', error);
        res.status(500).json({ error: error.message });
      }
    });
    
    app.get('/api/tick/:tickNumber', async (req, res) => {
      try {
        const tickNumber = parseInt(req.params.tickNumber);
        const tick = await tickExecutor.getExecutedTick(tickNumber);
        res.json(tick);
      } catch (error) {
        logger.error('Error fetching tick:', error);
        res.status(500).json({ error: error.message });
      }
    });
    
    app.get('/api/status', (req, res) => {
      res.json({
        relayer: wallet.address,
        queueSize: orderQueue.size(),
        lastProcessedTick: tickExecutor.lastProcessedTick,
        uptime: process.uptime()
      });
    });
    
    // Process ticks periodically (every 10ms for fast demo)
    setInterval(async () => {
      try {
        const orders = await orderQueue.getNextBatch(config.MAX_SWAPS_PER_TICK);
        if (orders.length > 0) {
          logger.info(`Processing batch of ${orders.length} orders...`);
          
          // In production, this would wait for VDF proof from Continuum
          // For demo, we generate a mock proof
          const tickNumber = tickExecutor.lastProcessedTick + 1;
          const proof = await vdfVerifier.generateMockProof(tickNumber, orders);
          
          // Execute on-chain
          await tickExecutor.executeTick(tickNumber, orders, proof);
          
          // Clear processed orders
          await orderQueue.clearBatch(orders);
        }
      } catch (error) {
        logger.error('Error in tick processing:', error);
      }
    }, 10); // 10ms interval
    
    // Start server
    const port = process.env.PORT || 8091;
    app.listen(port, () => {
      logger.info(`Relayer service running on port ${port}`);
    });
    
  } catch (error) {
    logger.error('Failed to initialize relayer:', error);
    process.exit(1);
  }
}

// Handle shutdown gracefully
process.on('SIGINT', () => {
  logger.info('Shutting down relayer...');
  process.exit(0);
});

// Start the relayer
initialize();