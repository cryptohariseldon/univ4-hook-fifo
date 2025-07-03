// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ContinuumSwapHook} from "../src/ContinuumSwapHook.sol";
import {ContinuumVerifier} from "../src/ContinuumVerifier.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

contract DeploySepoliaV4SimpleScript is Script {
    // Base Sepolia UNI-v4 addresses
    address constant BASE_SEPOLIA_POOL_MANAGER = 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Deploying Continuum Hook for UNI-v4 ===");
        console.log("Network: Base Sepolia Fork");
        console.log("Deployer:", deployer);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Continuum Verifier
        console.log("1. Deploying Continuum Verifier...");
        ContinuumVerifier verifier = new ContinuumVerifier();
        console.log("   Verifier deployed at:", address(verifier));
        
        // Deploy hook normally first
        console.log("");
        console.log("2. Deploying Continuum Hook...");
        ContinuumSwapHook hook = new ContinuumSwapHook(
            IPoolManager(BASE_SEPOLIA_POOL_MANAGER),
            verifier
        );
        console.log("   Hook deployed at:", address(hook));
        
        // Check hook permissions
        console.log("");
        console.log("3. Checking hook configuration...");
        uint160 hookAddr = uint160(address(hook));
        bool hasBeforeSwap = (hookAddr & Hooks.BEFORE_SWAP_FLAG) != 0;
        bool hasAfterSwap = (hookAddr & Hooks.AFTER_SWAP_FLAG) != 0;
        
        console.log("   Address:", address(hook));
        console.log("   Has beforeSwap permission:", hasBeforeSwap);
        console.log("   Has afterSwap permission:", hasAfterSwap);
        
        if (!hasBeforeSwap || !hasAfterSwap) {
            console.log("");
            console.log("   WARNING: Hook address doesn't have required permissions!");
            console.log("   In production, use CREATE2 with proper salt to get valid address");
        }
        
        // Authorize deployer as relayer
        console.log("");
        console.log("4. Authorizing relayer...");
        hook.authorizeRelayer(deployer, true);
        console.log("   Relayer authorized:", deployer);
        
        vm.stopBroadcast();
        
        // Save deployment info
        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("Verifier:", address(verifier));
        console.log("Hook:", address(hook));
        console.log("");
        console.log("Next steps:");
        console.log("1. Deploy test tokens or use existing ones");
        console.log("2. Create a pool with this hook (may need valid hook address)");
        console.log("3. Test swap execution");
        
        // Save addresses to env for next scripts
        vm.setEnv("VERIFIER_ADDRESS", vm.toString(address(verifier)));
        vm.setEnv("HOOK_ADDRESS", vm.toString(address(hook)));
    }
}