// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/ContinuumSwapHook.sol";
import "../src/ContinuumVerifier.sol";
import "../src/libraries/OrderStructs.sol";
import "../test/mocks/MockPoolManager.sol";
import "../test/mocks/MockERC20.sol";

contract TestIntegrationScript is Script {
    using OrderStructs for *;
    
    // Load deployed contracts from addresses
    ContinuumVerifier public verifier;
    ContinuumSwapHook public hook;
    MockPoolManager public poolManager;
    MockERC20 public usdc;
    MockERC20 public weth;
    
    address public relayer;
    address public alice = address(0x1111111111111111111111111111111111111111);
    address public bob = address(0x2222222222222222222222222222222222222222);
    
    PoolKey public usdcWethPool;
    
    function run() public {
        // Load deployment addresses from environment or file
        _loadDeployedContracts();
        
        // Get relayer private key
        uint256 relayerPrivateKey = vm.envUint("PRIVATE_KEY");
        relayer = vm.addr(relayerPrivateKey);
        
        // Create pool key
        usdcWethPool = PoolKey({
            currency0: Currency.wrap(address(usdc)),
            currency1: Currency.wrap(address(weth)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        console.log("=== Running Integration Test ===");
        console.log("Relayer:", relayer);
        
        // Test 1: Execute a single tick with multiple swaps
        console.log("\nTest 1: Executing tick with 3 swaps...");
        _testMultipleSwaps();
        
        // Test 2: Execute sequential ticks
        console.log("\nTest 2: Executing sequential ticks...");
        _testSequentialTicks();
        
        // Test 3: Test error cases
        console.log("\nTest 3: Testing error cases...");
        _testErrorCases();
        
        console.log("\n=== All tests completed successfully! ===");
    }
    
    function _loadDeployedContracts() internal {
        // In a real scenario, load from deployment file or env vars
        // For now, we'll use addresses from env
        verifier = ContinuumVerifier(vm.envAddress("VERIFIER_ADDRESS"));
        hook = ContinuumSwapHook(vm.envAddress("HOOK_ADDRESS"));
        poolManager = MockPoolManager(vm.envAddress("POOL_MANAGER_ADDRESS"));
        usdc = MockERC20(vm.envAddress("USDC_ADDRESS"));
        weth = MockERC20(vm.envAddress("WETH_ADDRESS"));
        
        console.log("Loaded contracts:");
        console.log("Verifier:", address(verifier));
        console.log("Hook:", address(hook));
        console.log("USDC:", address(usdc));
        console.log("WETH:", address(weth));
    }
    
    function _testMultipleSwaps() internal {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
        // Create 3 swap orders
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](3);
        
        // Alice: Buy WETH with 1000 USDC
        swaps[0] = OrderStructs.OrderedSwap({
            user: alice,
            poolKey: usdcWethPool,
            params: IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 1000e18,
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 1,
            signature: ""
        });
        
        // Bob: Sell 0.5 WETH for USDC
        swaps[1] = OrderStructs.OrderedSwap({
            user: bob,
            poolKey: usdcWethPool,
            params: IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 5e17,
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 2,
            signature: ""
        });
        
        // Alice: Buy more WETH with 2000 USDC
        swaps[2] = OrderStructs.OrderedSwap({
            user: alice,
            poolKey: usdcWethPool,
            params: IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 2000e18,
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 3,
            signature: ""
        });
        
        // Create VDF proof for tick 1
        bytes32 batchHash = verifier.computeBatchHash(swaps);
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), batchHash),
            output: abi.encodePacked(keccak256("tick1_output")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        // Check balances before
        uint256 aliceUsdcBefore = usdc.balanceOf(alice);
        uint256 aliceWethBefore = weth.balanceOf(alice);
        console.log("Alice USDC before:", aliceUsdcBefore / 1e18);
        console.log("Alice WETH before:", aliceWethBefore / 1e18);
        
        // Execute tick
        hook.executeTick(1, swaps, proof, bytes32(0));
        console.log("Tick 1 executed with 3 swaps");
        
        // Check balances after
        uint256 aliceUsdcAfter = usdc.balanceOf(alice);
        uint256 aliceWethAfter = weth.balanceOf(alice);
        console.log("Alice USDC after:", aliceUsdcAfter / 1e18);
        console.log("Alice WETH after:", aliceWethAfter / 1e18);
        
        vm.stopBroadcast();
    }
    
    function _testSequentialTicks() internal {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
        bytes32 previousOutput = keccak256(abi.encodePacked("tick1_output"));
        
        for (uint256 i = 2; i <= 5; i++) {
            // Create a simple swap
            OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](1);
            swaps[0] = OrderStructs.OrderedSwap({
                user: alice,
                poolKey: usdcWethPool,
                params: IPoolManager.SwapParams({
                    zeroForOne: true,
                    amountSpecified: 100e18,
                    sqrtPriceLimitX96: 0
                }),
                deadline: block.timestamp + 1 hours,
                sequenceNumber: i,
                signature: ""
            });
            
            // Create VDF proof
            bytes32 batchHash = verifier.computeBatchHash(swaps);
            OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
                input: abi.encodePacked(previousOutput, batchHash),
                output: abi.encodePacked(keccak256(abi.encodePacked("tick", i, "_output"))),
                proof: abi.encodePacked(uint256(i)),
                iterations: 27
            });
            
            // Execute tick
            hook.executeTick(i, swaps, proof, previousOutput);
            console.log("Tick", i, "executed");
            
            // Update previous output
            previousOutput = keccak256(proof.output);
        }
        
        console.log("Sequential ticks 2-5 executed successfully");
        
        vm.stopBroadcast();
    }
    
    function _testErrorCases() internal {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
        // Test 1: Try to execute tick out of sequence
        console.log("Testing out-of-sequence tick...");
        OrderStructs.VdfProof memory emptyProof = OrderStructs.VdfProof({
            input: "",
            output: "",
            proof: "",
            iterations: 0
        });
        try hook.executeTick(10, new OrderStructs.OrderedSwap[](0), emptyProof, bytes32(0)) {
            console.log("ERROR: Should have reverted!");
        } catch {
            console.log("OK: Correctly reverted on out-of-sequence tick");
        }
        
        // Test 2: Try to execute with expired deadline
        console.log("\nTesting expired deadline...");
        OrderStructs.OrderedSwap[] memory expiredSwaps = new OrderStructs.OrderedSwap[](1);
        expiredSwaps[0] = OrderStructs.OrderedSwap({
            user: alice,
            poolKey: usdcWethPool,
            params: IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 100e18,
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp - 1, // Expired
            sequenceNumber: 100,
            signature: ""
        });
        
        bytes32 batchHash = verifier.computeBatchHash(expiredSwaps);
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(verifier.lastVerifiedOutput(), batchHash),
            output: abi.encodePacked(keccak256("expired_output")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        try hook.executeTick(verifier.lastVerifiedTick() + 1, expiredSwaps, proof, verifier.lastVerifiedOutput()) {
            console.log("ERROR: Should have reverted!");
        } catch {
            console.log("OK: Correctly reverted on expired deadline");
        }
        
        vm.stopBroadcast();
    }
}