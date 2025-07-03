// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../../src/interfaces/IPoolManager.sol";
import "../../src/libraries/PoolKey.sol";
import "../../src/libraries/Currency.sol";
import "../../src/libraries/BalanceDelta.sol";
import "./MockERC20.sol";

contract MockPoolManager is IPoolManager {
    mapping(Currency => mapping(address => uint256)) public balances;
    
    function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData)
        external
        override
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
        
        return delta;
    }

    function modifyLiquidity(
        PoolKey memory key,
        ModifyLiquidityParams memory params,
        bytes calldata hookData
    ) external override returns (BalanceDelta delta, BalanceDelta feeDelta) {
        // Mock implementation
        delta = toBalanceDelta(int128(1000e18), int128(1000e18));
        feeDelta = toBalanceDelta(0, 0);
    }

    function donate(PoolKey memory key, uint256 amount0, uint256 amount1, bytes calldata hookData)
        external
        override
        returns (BalanceDelta delta)
    {
        delta = toBalanceDelta(int128(int256(amount0)), int128(int256(amount1)));
    }

    function take(Currency currency, address to, uint256 amount) external override {
        // Mock transfer tokens to user
        MockERC20(Currency.unwrap(currency)).transfer(to, amount);
        balances[currency][to] += amount;
    }

    function settle(Currency currency) external payable override returns (uint256 paid) {
        // Mock settle - user pays tokens
        uint256 balance = MockERC20(Currency.unwrap(currency)).balanceOf(msg.sender);
        if (balance > 0) {
            MockERC20(Currency.unwrap(currency)).transferFrom(msg.sender, address(this), balance);
            if (balances[currency][msg.sender] >= balance) {
                balances[currency][msg.sender] -= balance;
            }
        }
        return balance;
    }

    function mint(Currency currency, address to, uint256 amount) external override {
        MockERC20(Currency.unwrap(currency)).mint(to, amount);
    }

    function burn(Currency currency, uint256 amount) external override {
        MockERC20(Currency.unwrap(currency)).burn(msg.sender, amount);
    }
}