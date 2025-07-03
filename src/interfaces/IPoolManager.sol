// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "../libraries/PoolKey.sol";
import {Currency} from "../libraries/Currency.sol";
import {BalanceDelta} from "../libraries/BalanceDelta.sol";

interface IPoolManager {
    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }

    struct ModifyLiquidityParams {
        int24 tickLower;
        int24 tickUpper;
        int256 liquidityDelta;
        bytes32 salt;
    }

    function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData)
        external
        returns (BalanceDelta delta);

    function modifyLiquidity(PoolKey memory key, ModifyLiquidityParams memory params, bytes calldata hookData)
        external
        returns (BalanceDelta delta, BalanceDelta feeDelta);

    function donate(PoolKey memory key, uint256 amount0, uint256 amount1, bytes calldata hookData)
        external
        returns (BalanceDelta delta);

    function take(Currency currency, address to, uint256 amount) external;

    function settle(Currency currency) external payable returns (uint256 paid);

    function mint(Currency currency, address to, uint256 amount) external;

    function burn(Currency currency, uint256 amount) external;
}