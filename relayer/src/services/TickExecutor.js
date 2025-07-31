const { ethers } = require('ethers');
const config = require('../config');

class TickExecutor {
  constructor(contracts, wallet, logger) {
    this.contracts = contracts;
    this.wallet = wallet;
    this.logger = logger;
    this.lastProcessedTick = 1; // Start from tick 2 since tick 1 was used in demo
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
      
      // Orders should already be properly formatted from VDFVerifier
      const swaps = orders;
      
      // Execute on-chain
      this.logger.info(`Executing tick ${tickNumber} with ${swaps.length} swaps...`);
      
      // Debug logging
      this.logger.info(`Contract address: ${this.contracts.hook.target}`);
      this.logger.info(`Swap data: ${JSON.stringify(swaps[0])}`);
      this.logger.info(`Proof: ${JSON.stringify(proof)}`);
      
      let tx;
      try {
        // Encode the function call manually to debug
        const iface = this.contracts.hook.interface;
        const encodedData = iface.encodeFunctionData('executeTick', [
          tickNumber,
          swaps,
          proof,
          this.previousOutput
        ]);
        
        this.logger.info(`Encoded data length: ${encodedData.length}`);
        this.logger.info(`First 10 bytes: ${encodedData.slice(0, 20)}`);
        
        tx = await this.contracts.hook.executeTick(
          tickNumber,
          swaps,
          proof,
          this.previousOutput,
          {
            gasLimit: config.GAS_LIMIT,
            maxFeePerGas: ethers.parseUnits('20', 'gwei'),
            maxPriorityFeePerGas: ethers.parseUnits('2', 'gwei')
          }
        );
        
        this.logger.info(`Transaction submitted: ${tx.hash}`);
      } catch (encodeError) {
        this.logger.error(`Encoding error: ${encodeError.message}`);
        throw encodeError;
      }
      
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