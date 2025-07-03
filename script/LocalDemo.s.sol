// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/ContinuumSwapHook.sol";
import "../src/ContinuumVerifier.sol";
import "../src/libraries/OrderStructs.sol";
import "../test/mocks/MockPoolManager.sol";
import "../test/mocks/MockERC20.sol";

contract LocalDemoScript is Script {
    using OrderStructs for *;
    
    function run() public {
        // Use a local private key for demo
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Continuum UNI-v4 Hook Demo ===");
        console.log("Deployer:", deployer);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy contracts
        console.log("1. Deploying contracts...");
        MockERC20 usdc = new MockERC20("USD Coin", "USDC");
        MockERC20 weth = new MockERC20("Wrapped Ether", "WETH");
        MockPoolManager poolManager = new MockPoolManager();
        ContinuumVerifier verifier = new ContinuumVerifier();
        ContinuumSwapHook hook = new ContinuumSwapHook(IPoolManager(address(poolManager)), verifier);
        
        console.log("   USDC:", address(usdc));
        console.log("   WETH:", address(weth));
        console.log("   Verifier:", address(verifier));
        console.log("   Hook:", address(hook));
        console.log("");
        
        // Setup test users
        address alice = address(0x1111);
        address bob = address(0x2222);
        
        console.log("2. Setting up test users...");
        usdc.mint(alice, 10000e18);
        weth.mint(alice, 10e18);
        usdc.mint(bob, 10000e18);
        weth.mint(bob, 10e18);
        console.log("   Alice funded with 10,000 USDC and 10 WETH");
        console.log("   Bob funded with 10,000 USDC and 10 WETH");
        console.log("");
        
        // Create pool
        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(address(usdc)),
            currency1: Currency.wrap(address(weth)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        // Simulate Continuum ordering
        console.log("3. Simulating Continuum tick with 2 swaps...");
        
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](2);
        
        swaps[0] = OrderStructs.OrderedSwap({
            user: alice,
            poolKey: pool,
            params: IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 1000e18,
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 1,
            signature: ""
        });
        
        swaps[1] = OrderStructs.OrderedSwap({
            user: bob,
            poolKey: pool,
            params: IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 1e18,
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 2,
            signature: ""
        });
        
        // Create mock VDF proof
        bytes32 batchHash = verifier.computeBatchHash(swaps);
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), batchHash),
            output: abi.encodePacked(keccak256("demo_tick")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        // Execute tick
        hook.executeTick(1, swaps, proof, bytes32(0));
        
        console.log("   Tick 1 executed successfully!");
        console.log("   - Alice swapped 1000 USDC for WETH");
        console.log("   - Bob swapped 1 WETH for USDC");
        console.log("");
        
        // Show results
        console.log("4. Final balances:");
        console.log("   Alice WETH:", weth.balanceOf(alice) / 1e18, "WETH");
        console.log("   Bob USDC:", usdc.balanceOf(bob) / 1e18, "USDC");
        console.log("");
        
        console.log("=== Demo Complete! ===");
        console.log("This demonstrates how Continuum prevents frontrunning by:");
        console.log("- Ordering all swaps through VDF-based sequencing");
        console.log("- Executing swaps in exact order determined by Continuum");
        console.log("- Preventing direct access to the pool");
        
        vm.stopBroadcast();
    }
}