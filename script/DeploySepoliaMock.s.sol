// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ContinuumSwapHook} from "../src/ContinuumSwapHook.sol";
import {ContinuumVerifier} from "../src/ContinuumVerifier.sol";
import {SimpleMockPoolManager} from "../test/mocks/SimpleMockPoolManager.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

contract DeploySepoliaMockScript is Script {
    function run() public returns (
        ContinuumVerifier verifier,
        ContinuumSwapHook hook,
        SimpleMockPoolManager poolManager,
        MockERC20 usdc,
        MockERC20 weth
    ) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Deploying Continuum Demo on Sepolia ===");
        console.log("Network: Ethereum Sepolia");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance / 1e18, "ETH");
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock tokens
        console.log("1. Deploying mock tokens...");
        usdc = new MockERC20("USD Coin", "USDC");
        weth = new MockERC20("Wrapped Ether", "WETH");
        console.log("   USDC deployed at:", address(usdc));
        console.log("   WETH deployed at:", address(weth));
        
        // Deploy mock pool manager
        console.log("");
        console.log("2. Deploying mock pool manager...");
        poolManager = new SimpleMockPoolManager();
        console.log("   Pool Manager deployed at:", address(poolManager));
        
        // Deploy Continuum contracts
        console.log("");
        console.log("3. Deploying Continuum Verifier...");
        verifier = new ContinuumVerifier();
        console.log("   Verifier deployed at:", address(verifier));
        
        console.log("");
        console.log("4. Deploying Continuum Hook...");
        hook = new ContinuumSwapHook(
            IPoolManager(address(poolManager)),
            verifier
        );
        console.log("   Hook deployed at:", address(hook));
        
        // Authorize deployer as relayer
        console.log("");
        console.log("5. Setting up permissions...");
        hook.authorizeRelayer(deployer, true);
        console.log("   Relayer authorized:", deployer);
        
        // Mint tokens for testing
        console.log("");
        console.log("6. Minting test tokens...");
        address alice = address(0x1111111111111111111111111111111111111111);
        address bob = address(0x2222222222222222222222222222222222222222);
        
        usdc.mint(alice, 10000e18);
        usdc.mint(bob, 10000e18);
        weth.mint(alice, 10e18);
        weth.mint(bob, 10e18);
        usdc.mint(address(poolManager), 100000e18);
        weth.mint(address(poolManager), 100e18);
        
        console.log("   Minted tokens to test users and pool");
        
        vm.stopBroadcast();
        
        // Display summary
        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("Verifier:", address(verifier));
        console.log("Hook:", address(hook));
        console.log("Pool Manager:", address(poolManager));
        console.log("USDC:", address(usdc));
        console.log("WETH:", address(weth));
        console.log("");
        console.log("Gas used:", deployer.balance / 1e18, "ETH remaining");
        console.log("");
        console.log("Next: Run TestIntegration script to demo swaps");
        
        // Return deployed contracts
        return (verifier, hook, poolManager, usdc, weth);
    }
}