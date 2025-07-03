// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "../interfaces/IHooks.sol";

library Hooks {
    uint256 internal constant BEFORE_INITIALIZE_FLAG = 1 << 159;
    uint256 internal constant AFTER_INITIALIZE_FLAG = 1 << 158;
    uint256 internal constant BEFORE_ADD_LIQUIDITY_FLAG = 1 << 157;
    uint256 internal constant AFTER_ADD_LIQUIDITY_FLAG = 1 << 156;
    uint256 internal constant BEFORE_REMOVE_LIQUIDITY_FLAG = 1 << 155;
    uint256 internal constant AFTER_REMOVE_LIQUIDITY_FLAG = 1 << 154;
    uint256 internal constant BEFORE_SWAP_FLAG = 1 << 153;
    uint256 internal constant AFTER_SWAP_FLAG = 1 << 152;
    uint256 internal constant BEFORE_DONATE_FLAG = 1 << 151;
    uint256 internal constant AFTER_DONATE_FLAG = 1 << 150;
    uint256 internal constant BEFORE_SWAP_RETURNS_DELTA_FLAG = 1 << 149;
    uint256 internal constant AFTER_SWAP_RETURNS_DELTA_FLAG = 1 << 148;
    uint256 internal constant AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG = 1 << 147;
    uint256 internal constant AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG = 1 << 146;

    struct Permissions {
        bool beforeInitialize;
        bool afterInitialize;
        bool beforeAddLiquidity;
        bool afterAddLiquidity;
        bool beforeRemoveLiquidity;
        bool afterRemoveLiquidity;
        bool beforeSwap;
        bool afterSwap;
        bool beforeDonate;
        bool afterDonate;
        bool beforeSwapReturnDelta;
        bool afterSwapReturnDelta;
        bool afterAddLiquidityReturnDelta;
        bool afterRemoveLiquidityReturnDelta;
    }

    function validateHookPermissions(IHooks self, Permissions memory permissions) internal pure {
        if (
            permissions.beforeInitialize != shouldCallBeforeInitialize(self)
                || permissions.afterInitialize != shouldCallAfterInitialize(self)
                || permissions.beforeAddLiquidity != shouldCallBeforeAddLiquidity(self)
                || permissions.afterAddLiquidity != shouldCallAfterAddLiquidity(self)
                || permissions.beforeRemoveLiquidity != shouldCallBeforeRemoveLiquidity(self)
                || permissions.afterRemoveLiquidity != shouldCallAfterRemoveLiquidity(self)
                || permissions.beforeSwap != shouldCallBeforeSwap(self)
                || permissions.afterSwap != shouldCallAfterSwap(self)
                || permissions.beforeDonate != shouldCallBeforeDonate(self)
                || permissions.afterDonate != shouldCallAfterDonate(self)
                || permissions.beforeSwapReturnDelta != hasPermission(self, BEFORE_SWAP_RETURNS_DELTA_FLAG)
                || permissions.afterSwapReturnDelta != hasPermission(self, AFTER_SWAP_RETURNS_DELTA_FLAG)
                || permissions.afterAddLiquidityReturnDelta != hasPermission(self, AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG)
                || permissions.afterRemoveLiquidityReturnDelta != hasPermission(self, AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG)
        ) {
            revert HookAddressNotValid(address(self));
        }
    }

    function isValidHookAddress(IHooks self, uint24 fee) internal pure returns (bool) {
        uint160 addr = uint160(address(self));
        if (uint160(uint24(addr)) != fee) return false;

        uint256 hookFlags = addr >> 8;
        
        // Check that only valid flags are set
        uint256 allFlags = BEFORE_INITIALIZE_FLAG | AFTER_INITIALIZE_FLAG | BEFORE_ADD_LIQUIDITY_FLAG
            | AFTER_ADD_LIQUIDITY_FLAG | BEFORE_REMOVE_LIQUIDITY_FLAG | AFTER_REMOVE_LIQUIDITY_FLAG
            | BEFORE_SWAP_FLAG | AFTER_SWAP_FLAG | BEFORE_DONATE_FLAG | AFTER_DONATE_FLAG
            | BEFORE_SWAP_RETURNS_DELTA_FLAG | AFTER_SWAP_RETURNS_DELTA_FLAG
            | AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG | AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG;
            
        if (hookFlags & ~allFlags != 0) return false;
        
        return true;
    }

    function hasPermission(IHooks self, uint256 flag) internal pure returns (bool) {
        return uint256(uint160(address(self))) & flag != 0;
    }

    function shouldCallBeforeInitialize(IHooks self) internal pure returns (bool) {
        return hasPermission(self, BEFORE_INITIALIZE_FLAG);
    }

    function shouldCallAfterInitialize(IHooks self) internal pure returns (bool) {
        return hasPermission(self, AFTER_INITIALIZE_FLAG);
    }

    function shouldCallBeforeAddLiquidity(IHooks self) internal pure returns (bool) {
        return hasPermission(self, BEFORE_ADD_LIQUIDITY_FLAG);
    }

    function shouldCallAfterAddLiquidity(IHooks self) internal pure returns (bool) {
        return hasPermission(self, AFTER_ADD_LIQUIDITY_FLAG);
    }

    function shouldCallBeforeRemoveLiquidity(IHooks self) internal pure returns (bool) {
        return hasPermission(self, BEFORE_REMOVE_LIQUIDITY_FLAG);
    }

    function shouldCallAfterRemoveLiquidity(IHooks self) internal pure returns (bool) {
        return hasPermission(self, AFTER_REMOVE_LIQUIDITY_FLAG);
    }

    function shouldCallBeforeSwap(IHooks self) internal pure returns (bool) {
        return hasPermission(self, BEFORE_SWAP_FLAG);
    }

    function shouldCallAfterSwap(IHooks self) internal pure returns (bool) {
        return hasPermission(self, AFTER_SWAP_FLAG);
    }

    function shouldCallBeforeDonate(IHooks self) internal pure returns (bool) {
        return hasPermission(self, BEFORE_DONATE_FLAG);
    }

    function shouldCallAfterDonate(IHooks self) internal pure returns (bool) {
        return hasPermission(self, AFTER_DONATE_FLAG);
    }

    error HookAddressNotValid(address hook);
}