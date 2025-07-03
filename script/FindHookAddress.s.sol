// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ContinuumSwapHook} from "../src/ContinuumSwapHook.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

contract FindHookAddressScript is Script {
    // Required hook permissions for our use case
    uint256 constant REQUIRED_PERMISSIONS = 
        Hooks.BEFORE_SWAP_FLAG | 
        Hooks.AFTER_SWAP_FLAG;
    
    function run() public view {
        console.log("=== Finding Valid Hook Address ===");
        console.log("Required permissions:");
        console.log("- beforeSwap: true");
        console.log("- afterSwap: true");
        console.log("");
        
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        address poolManager = vm.envAddress("POOL_MANAGER_ADDRESS");
        address verifier = vm.envAddress("VERIFIER_ADDRESS");
        
        // Try different salts to find valid address
        for (uint256 i = 0; i < 100000; i++) {
            bytes32 salt = bytes32(i);
            address hookAddress = computeCreate2Address(
                salt,
                deployer,
                poolManager,
                verifier
            );
            
            if (isValidHookAddress(hookAddress)) {
                console.log("Found valid hook address!");
                console.log("Salt:", uint256(salt));
                console.log("Address:", hookAddress);
                console.log("");
                console.log("To deploy, use this salt in deployment script");
                return;
            }
            
            if (i % 10000 == 0) {
                console.log("Checked", i, "addresses...");
            }
        }
        
        console.log("No valid address found in first 100k attempts");
        console.log("Try increasing search range or adjusting requirements");
    }
    
    function computeCreate2Address(
        bytes32 salt,
        address deployer,
        address poolManager,
        address verifier
    ) internal pure returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(ContinuumSwapHook).creationCode,
            abi.encode(poolManager, verifier)
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                deployer,
                salt,
                keccak256(bytecode)
            )
        );
        
        return address(uint160(uint256(hash)));
    }
    
    function isValidHookAddress(address hookAddress) internal pure returns (bool) {
        uint160 addr = uint160(hookAddress);
        
        // Check if required permission bits are set
        if ((addr & REQUIRED_PERMISSIONS) != REQUIRED_PERMISSIONS) {
            return false;
        }
        
        // Check that no invalid flags are set
        uint256 allValidFlags = 
            Hooks.BEFORE_INITIALIZE_FLAG |
            Hooks.AFTER_INITIALIZE_FLAG |
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.AFTER_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG |
            Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.AFTER_SWAP_FLAG |
            Hooks.BEFORE_DONATE_FLAG |
            Hooks.AFTER_DONATE_FLAG |
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG |
            Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG |
            Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG |
            Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG;
            
        if ((addr & ~allValidFlags) != 0) {
            return false;
        }
        
        return true;
    }
    
    function getPermissionString(address hookAddress) internal pure returns (string memory) {
        uint160 addr = uint160(hookAddress);
        string memory permissions = "";
        
        if (addr & Hooks.BEFORE_SWAP_FLAG != 0) permissions = string.concat(permissions, "beforeSwap,");
        if (addr & Hooks.AFTER_SWAP_FLAG != 0) permissions = string.concat(permissions, "afterSwap,");
        if (addr & Hooks.BEFORE_ADD_LIQUIDITY_FLAG != 0) permissions = string.concat(permissions, "beforeAddLiquidity,");
        if (addr & Hooks.AFTER_ADD_LIQUIDITY_FLAG != 0) permissions = string.concat(permissions, "afterAddLiquidity,");
        // ... add more as needed
        
        return permissions;
    }
}