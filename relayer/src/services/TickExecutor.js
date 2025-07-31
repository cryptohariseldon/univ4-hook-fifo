const { ethers } = require('ethers');
const config = require('../config');

class TickExecutor {
  constructor(contracts, wallet, logger) {
    this.contracts = contracts;
    this.wallet = wallet;
    this.logger = logger;
    this.lastProcessedTick = 0;
    this.previousOutput = ethers.ZeroHash;
  }
  
  async executeTick(tickNumber, orders, proof) {
    try {
      if (!this.contracts.hook) {
        this.logger.warn('No hook contract configured, simulating execution...');
        this.lastProcessedTick = tickNumber;
        return {
          success: true,
          tickNumber,
          orderCount: orders.length,
          simulated: true
        };
      }
      
      // Prepare swap data for contract
      const swaps = orders.map((order, index) => ({
        user: order.user,
        poolKey: order.poolKey,
        params: order.params,
        deadline: order.deadline || Math.floor(Date.now() / 1000) + config.ORDER_VALIDITY_SECONDS,
        sequenceNumber: order.sequenceNumber || (tickNumber * 1000 + index),
        signature: order.signature || '0x'
      }));
      
      // Execute on-chain
      this.logger.info(`Executing tick ${tickNumber} with ${swaps.length} swaps...`);
      
      // Format the swaps properly for the contract
      const formattedSwaps = swaps.map(swap => ({
        user: swap.user,
        poolKey: {
          currency0: swap.poolKey.currency0,
          currency1: swap.poolKey.currency1,
          fee: swap.poolKey.fee,
          tickSpacing: swap.poolKey.tickSpacing,
          hooks: swap.poolKey.hooks
        },
        params: {
          zeroForOne: swap.params.zeroForOne,
          amountSpecified: swap.params.amountSpecified,
          sqrtPriceLimitX96: swap.params.sqrtPriceLimitX96
        },
        deadline: swap.deadline,
        sequenceNumber: swap.sequenceNumber,
        signature: swap.signature || '0x'
      }));
      
      const tx = await this.contracts.hook.executeTick(
        tickNumber,
        formattedSwaps,
        proof,
        this.previousOutput,
        {
          gasLimit: config.GAS_LIMIT,
          maxFeePerGas: ethers.parseUnits('20', 'gwei'),
          maxPriorityFeePerGas: ethers.parseUnits('2', 'gwei')
        }
      );
      
      this.logger.info(`Transaction submitted: ${tx.hash}`);
      
      const receipt = await tx.wait();
      this.logger.info(`Tick ${tickNumber} executed successfully. Gas used: ${receipt.gasUsed.toString()}`);
      
      // Update state
      this.lastProcessedTick = tickNumber;
      this.previousOutput = proof.output;
      
      return {
        success: true,
        tickNumber,
        orderCount: swaps.length,
        transactionHash: tx.hash,
        gasUsed: receipt.gasUsed.toString()
      };
      
    } catch (error) {
      this.logger.error(`Failed to execute tick ${tickNumber}:`, error);
      throw error;
    }
  }
  
  async getExecutedTick(tickNumber) {
    if (!this.contracts.hook) {
      return null;
    }
    
    try {
      const tick = await this.contracts.hook.getExecutedTick(tickNumber);
      return {
        tickNumber: tick.tickNumber.toString(),
        swapCount: tick.swaps.length,
        batchHash: tick.batchHash,
        timestamp: tick.timestamp.toString(),
        previousOutput: tick.previousOutput
      };
    } catch (error) {
      this.logger.error(`Failed to fetch tick ${tickNumber}:`, error);
      return null;
    }
  }
}

module.exports = TickExecutor;