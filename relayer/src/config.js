module.exports = {
  // Maximum swaps per Continuum tick
  MAX_SWAPS_PER_TICK: 100,
  
  // Tick interval in seconds (using 0.01 seconds = 10ms for fast demo)
  TICK_INTERVAL: 0.01,
  
  // Default gas settings
  GAS_LIMIT: 2000000,
  GAS_PRICE_MULTIPLIER: 1.2,
  
  // VDF iterations for demo (production would use actual Continuum values)
  VDF_ITERATIONS: 27,
  
  // Order validity period (1 hour)
  ORDER_VALIDITY_SECONDS: 3600,
  
  // Retry settings
  MAX_RETRIES: 3,
  RETRY_DELAY_MS: 1000
};