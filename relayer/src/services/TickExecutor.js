const { ethers } = require('ethers');
const config = require('../config');

class TickExecutor {
  constructor(contracts, wallet, logger) {
    this.contracts = contracts;
    this.wallet = wallet;
    this.logger = logger;
    this.lastProcessedTick = 1; // Start from tick 2 since tick 1 was used in demo
    // Get the previous output from tick 1 that was executed in demo
    this.previousOutput = ethers.ZeroHash; // We'll update this after first query
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
        
        // Send transaction directly with encoded data
        const txRequest = {
          to: this.contracts.hook.target,
          data: encodedData,
          gasLimit: config.GAS_LIMIT,
          maxFeePerGas: ethers.parseUnits('20', 'gwei'),
          maxPriorityFeePerGas: ethers.parseUnits('2', 'gwei'),
          type: 2 // EIP-1559 transaction
        };
        
        this.logger.info(`=== TRANSACTION DEBUG INFO ===`);
        this.logger.info(`To: ${txRequest.to}`);
        this.logger.info(`From: ${this.wallet.address}`);
        this.logger.info(`Data length: ${txRequest.data.length} bytes`);
        this.logger.info(`Data (first 100 chars): ${txRequest.data.slice(0, 100)}...`);
        this.logger.info(`Gas limit: ${txRequest.gasLimit}`);
        this.logger.info(`Max fee per gas: ${ethers.formatUnits(txRequest.maxFeePerGas, 'gwei')} gwei`);
        this.logger.info(`Max priority fee: ${ethers.formatUnits(txRequest.maxPriorityFeePerGas, 'gwei')} gwei`);
        
        // Check wallet balance
        const balance = await this.wallet.provider.getBalance(this.wallet.address);
        this.logger.info(`Wallet balance: ${ethers.formatEther(balance)} ETH`);
        
        // Estimate gas
        try {
          const estimatedGas = await this.wallet.estimateGas(txRequest);
          this.logger.info(`Estimated gas: ${estimatedGas.toString()}`);
        } catch (gasError) {
          this.logger.error(`Gas estimation failed: ${gasError.message}`);
          // Try to get revert reason
          if (gasError.data) {
            this.logger.error(`Revert data: ${gasError.data}`);
            try {
              const reason = ethers.AbiCoder.defaultAbiCoder().decode(['string'], ethers.dataSlice(gasError.data, 4));
              this.logger.error(`Decoded revert reason: ${reason}`);
            } catch (decodeError) {
              this.logger.error(`Could not decode revert reason`);
            }
          }
        }
        
        this.logger.info(`Sending transaction...`);
        tx = await this.wallet.sendTransaction(txRequest);
        
        this.logger.info(`Transaction sent!`);
        this.logger.info(`Hash: ${tx.hash}`);
        this.logger.info(`Nonce: ${tx.nonce}`);
        this.logger.info(`Gas limit: ${tx.gasLimit.toString()}`);
        
        this.logger.info(`Transaction submitted: ${tx.hash}`);
      } catch (encodeError) {
        this.logger.error(`Encoding error: ${encodeError.message}`);
        throw encodeError;
      }
      
      this.logger.info(`Waiting for transaction confirmation...`);
      const receipt = await tx.wait();
      
      this.logger.info(`=== TRANSACTION RECEIPT ===`);
      this.logger.info(`Status: ${receipt.status === 1 ? 'SUCCESS' : 'FAILED'}`);
      this.logger.info(`Block number: ${receipt.blockNumber}`);
      this.logger.info(`Gas used: ${receipt.gasUsed.toString()}`);
      this.logger.info(`Effective gas price: ${ethers.formatUnits(receipt.gasPrice, 'gwei')} gwei`);
      this.logger.info(`Total cost: ${ethers.formatEther(receipt.gasUsed * receipt.gasPrice)} ETH`);
      
      if (receipt.logs.length > 0) {
        this.logger.info(`Logs emitted: ${receipt.logs.length}`);
        receipt.logs.forEach((log, index) => {
          this.logger.info(`Log ${index}: ${log.topics[0]}`);
        });
      }
      
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