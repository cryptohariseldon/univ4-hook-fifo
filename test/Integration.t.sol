// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/ContinuumSwapHook.sol";
import "../src/ContinuumVerifier.sol";
import "../src/libraries/OrderStructs.sol";
import "./mocks/SimpleMockPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import "./mocks/MockERC20.sol";

contract IntegrationTest is Test {
    using OrderStructs for *;

    ContinuumSwapHook public hook;
    ContinuumVerifier public verifier;
    SimpleMockPoolManager public poolManager;
    
    MockERC20 public usdc;
    MockERC20 public weth;
    
    address public relayer = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    
    PoolKey public usdcWethPool;
    
    function setUp() public {
        // Deploy infrastructure
        poolManager = new SimpleMockPoolManager();
        usdc = new MockERC20("USD Coin", "USDC");
        weth = new MockERC20("Wrapped Ether", "WETH");
        
        verifier = new ContinuumVerifier();
        hook = new ContinuumSwapHook(IPoolManager(address(poolManager)), verifier);
        
        // Create pool
        usdcWethPool = PoolKey({
            currency0: Currency.wrap(address(usdc)),
            currency1: Currency.wrap(address(weth)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        // Setup participants
        hook.authorizeRelayer(relayer, true);
        
        // Fund users
        usdc.mint(alice, 10000e18);
        weth.mint(alice, 10e18);
        usdc.mint(bob, 10000e18);
        weth.mint(bob, 10e18);
        usdc.mint(charlie, 10000e18);
        weth.mint(charlie, 10e18);
        
        // Approve pool manager
        vm.prank(alice);
        usdc.approve(address(poolManager), type(uint256).max);
        vm.prank(alice);
        weth.approve(address(poolManager), type(uint256).max);
        
        vm.prank(bob);
        usdc.approve(address(poolManager), type(uint256).max);
        vm.prank(bob);
        weth.approve(address(poolManager), type(uint256).max);
        
        vm.prank(charlie);
        usdc.approve(address(poolManager), type(uint256).max);
        vm.prank(charlie);
        weth.approve(address(poolManager), type(uint256).max);
    }

    function testFullSwapFlow() public {
        // Simulate 3 users submitting swap orders to Continuum
        // Alice: Buy 1 WETH with USDC
        // Bob: Sell 0.5 WETH for USDC  
        // Charlie: Buy 2 WETH with USDC
        
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](3);
        
        // Alice's order
        swaps[0] = OrderStructs.OrderedSwap({
            user: alice,
            poolKey: usdcWethPool,
            params: IPoolManager.SwapParams({
                zeroForOne: true, // USDC -> WETH
                amountSpecified: 3000e18, // 3000 USDC
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 1,
            signature: ""
        });
        
        // Bob's order
        swaps[1] = OrderStructs.OrderedSwap({
            user: bob,
            poolKey: usdcWethPool,
            params: IPoolManager.SwapParams({
                zeroForOne: false, // WETH -> USDC
                amountSpecified: 500000000000000000, // 0.5 WETH
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 2,
            signature: ""
        });
        
        // Charlie's order
        swaps[2] = OrderStructs.OrderedSwap({
            user: charlie,
            poolKey: usdcWethPool,
            params: IPoolManager.SwapParams({
                zeroForOne: true, // USDC -> WETH
                amountSpecified: 6000e18, // 6000 USDC
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 3,
            signature: ""
        });
        
        // Record initial balances
        uint256 aliceUsdcBefore = usdc.balanceOf(alice);
        uint256 aliceWethBefore = weth.balanceOf(alice);
        uint256 bobUsdcBefore = usdc.balanceOf(bob);
        uint256 bobWethBefore = weth.balanceOf(bob);
        
        // Create VDF proof for tick 1
        bytes32 batchHash = verifier.computeBatchHash(swaps);
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), batchHash),
            output: abi.encodePacked(keccak256("tick1_output")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        // Execute tick as relayer
        vm.prank(relayer);
        hook.executeTick(1, swaps, proof, bytes32(0));
        
        // Verify execution
        assertTrue(verifier.isTickExecuted(1));
        assertEq(hook.totalSwapsExecuted(), 3);
        
        // Check balances changed (in our mock, tokens are created/transferred)
        // Alice should have received WETH
        assertTrue(weth.balanceOf(alice) > aliceWethBefore);
        // Bob should have received USDC
        assertTrue(usdc.balanceOf(bob) > bobUsdcBefore);
        // Charlie should have received WETH
        assertTrue(weth.balanceOf(charlie) > weth.balanceOf(alice));
    }

    function testMultipleTicksSequential() public {
        // Execute multiple ticks in sequence
        for (uint256 i = 1; i <= 5; i++) {
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
            
            bytes32 batchHash = verifier.computeBatchHash(swaps);
            bytes32 previousOutput = i == 1 ? bytes32(0) : keccak256(abi.encodePacked("output", i - 1));
            
            OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
                input: abi.encodePacked(previousOutput, batchHash),
                output: abi.encodePacked("output", i),
                proof: abi.encodePacked(uint256(i)),
                iterations: 27
            });
            
            vm.prank(relayer);
            hook.executeTick(i, swaps, proof, previousOutput);
        }
        
        assertEq(hook.totalSwapsExecuted(), 5);
        assertEq(verifier.lastVerifiedTick(), 5);
    }

    function testInvalidOrderRejection() public {
        // Try to submit order with wrong tick sequence
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](1);
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), keccak256("batch")),
            output: abi.encodePacked(keccak256("output")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        // Skip tick 1 and try tick 2
        vm.prank(relayer);
        vm.expectRevert(ContinuumVerifier.InvalidTickSequence.selector);
        hook.executeTick(2, swaps, proof, bytes32(0));
    }

    function testOrderDuplication() public {
        // Create identical order
        OrderStructs.OrderedSwap memory swap = OrderStructs.OrderedSwap({
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
        
        // First execution
        OrderStructs.OrderedSwap[] memory swaps1 = new OrderStructs.OrderedSwap[](1);
        swaps1[0] = swap;
        
        bytes32 batchHash1 = verifier.computeBatchHash(swaps1);
        OrderStructs.VdfProof memory proof1 = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), batchHash1),
            output: abi.encodePacked(keccak256("output1")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        vm.prank(relayer);
        hook.executeTick(1, swaps1, proof1, bytes32(0));
        
        // Try same order in tick 2
        OrderStructs.OrderedSwap[] memory swaps2 = new OrderStructs.OrderedSwap[](1);
        swaps2[0] = swap; // Same order
        
        bytes32 previousOutput = keccak256(proof1.output);
        bytes32 batchHash2 = verifier.computeBatchHash(swaps2);
        OrderStructs.VdfProof memory proof2 = OrderStructs.VdfProof({
            input: abi.encodePacked(previousOutput, batchHash2),
            output: abi.encodePacked(keccak256("output2")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        vm.prank(relayer);
        vm.expectRevert(ContinuumSwapHook.OrderAlreadyExecuted.selector);
        hook.executeTick(2, swaps2, proof2, previousOutput);
    }

    function testGasOptimization() public {
        // Test batch execution gas usage
        uint256[] memory gasCosts = new uint256[](3);
        
        // Single swap
        OrderStructs.OrderedSwap[] memory swaps1 = _createSwaps(1);
        uint256 gasStart = gasleft();
        _executeTick(1, swaps1, bytes32(0));
        gasCosts[0] = gasStart - gasleft();
        
        // 10 swaps
        OrderStructs.OrderedSwap[] memory swaps10 = _createSwaps(10);
        // Get the actual previous output from verifier
        bytes32 prevOutput = verifier.getTickOutput(1);
        gasStart = gasleft();
        _executeTick(2, swaps10, prevOutput);
        gasCosts[1] = gasStart - gasleft();
        
        // 50 swaps
        OrderStructs.OrderedSwap[] memory swaps50 = _createSwaps(50);
        // Get the actual previous output from verifier
        prevOutput = verifier.getTickOutput(2);
        gasStart = gasleft();
        _executeTick(3, swaps50, prevOutput);
        gasCosts[2] = gasStart - gasleft();
        
        // Log gas costs
        console.log("Gas cost for 1 swap:", gasCosts[0]);
        console.log("Gas cost for 10 swaps:", gasCosts[1]);
        console.log("Gas cost for 50 swaps:", gasCosts[2]);
        console.log("Gas per swap (10 batch):", gasCosts[1] / 10);
        console.log("Gas per swap (50 batch):", gasCosts[2] / 50);
    }

    function _createSwaps(uint256 count) internal returns (OrderStructs.OrderedSwap[] memory) {
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](count);
        
        for (uint256 i = 0; i < count; i++) {
            swaps[i] = OrderStructs.OrderedSwap({
                user: alice,
                poolKey: usdcWethPool,
                params: IPoolManager.SwapParams({
                    zeroForOne: true,
                    amountSpecified: 100e18,
                    sqrtPriceLimitX96: 0
                }),
                deadline: block.timestamp + 1 hours,
                sequenceNumber: hook.totalSwapsExecuted() + i + 1,
                signature: ""
            });
        }
        
        return swaps;
    }

    function _executeTick(uint256 tickNumber, OrderStructs.OrderedSwap[] memory swaps, bytes32 previousOutput) internal {
        bytes32 batchHash = verifier.computeBatchHash(swaps);
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(previousOutput, batchHash),
            output: abi.encodePacked("output", tickNumber),
            proof: abi.encodePacked(uint256(tickNumber)),
            iterations: 27
        });
        
        vm.prank(relayer);
        hook.executeTick(tickNumber, swaps, proof, previousOutput);
    }
}