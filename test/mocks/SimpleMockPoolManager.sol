// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDelta, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";
import "./MockERC20.sol";

// Minimal implementation for testing only swap functionality
contract SimpleMockPoolManager {
    mapping(Currency => mapping(address => uint256)) public balances;
    
    function swap(PoolKey memory key, IPoolManager.SwapParams memory params, bytes calldata hookData)
        external
        returns (BalanceDelta delta)
    {
        // Simple mock swap logic
        if (params.zeroForOne) {
            // User provides token0, receives token1
            int128 amount0 = int128(params.amountSpecified);
            int128 amount1 = -int128(params.amountSpecified * 95 / 100); // 5% slippage
            delta = toBalanceDelta(amount0, amount1);
        } else {
            // User provides token1, receives token0
            int128 amount1 = int128(params.amountSpecified);
            int128 amount0 = -int128(params.amountSpecified * 95 / 100); // 5% slippage
            delta = toBalanceDelta(amount0, amount1);
        }
        
        // Call hooks
        address hooks = address(key.hooks);
        if (hooks != address(0)) {
            // Call beforeSwap
            key.hooks.beforeSwap(msg.sender, key, params, hookData);
            // Call afterSwap
            key.hooks.afterSwap(msg.sender, key, params, delta, hookData);
        }
    }
    
    function modifyLiquidity(PoolKey memory key, IPoolManager.ModifyLiquidityParams memory params, bytes calldata hookData)
        external
        returns (BalanceDelta, BalanceDelta)
    {
        // Mock implementation
        return (toBalanceDelta(0, 0), toBalanceDelta(0, 0));
    }
    
    function initialize(PoolKey memory key, uint160 sqrtPriceX96) external returns (int24) {
        // Mock implementation
        return 0;
    }
    
    function donate(PoolKey memory key, uint256 amount0, uint256 amount1, bytes calldata hookData) external returns (BalanceDelta) {
        // Mock implementation
        return toBalanceDelta(0, 0);
    }
    
    function take(Currency currency, address to, uint256 amount) external {
        // Mock transfer tokens to user
        MockERC20(Currency.unwrap(currency)).transfer(to, amount);
        balances[currency][to] += amount;
    }
}