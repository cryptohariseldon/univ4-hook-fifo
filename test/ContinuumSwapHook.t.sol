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
import "./mocks/MockERC20.sol";

contract ContinuumSwapHookTest is Test {
    using OrderStructs for *;

    ContinuumSwapHook public hook;
    ContinuumVerifier public verifier;
    SimpleMockPoolManager public poolManager;
    
    MockERC20 public token0;
    MockERC20 public token1;
    
    address public relayer = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    PoolKey public testPoolKey;
    
    function setUp() public {
        // Deploy mocks
        poolManager = new SimpleMockPoolManager();
        token0 = new MockERC20("Token0", "TK0");
        token1 = new MockERC20("Token1", "TK1");
        
        // Deploy verifier and hook
        verifier = new ContinuumVerifier();
        hook = new ContinuumSwapHook(IPoolManager(address(poolManager)), verifier);
        
        // Setup pool key
        testPoolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        // Authorize relayer
        hook.authorizeRelayer(relayer, true);
        
        // Fund users
        token0.mint(user1, 1000e18);
        token1.mint(user1, 1000e18);
        token0.mint(user2, 1000e18);
        token1.mint(user2, 1000e18);
        
        // Approve pool manager
        vm.prank(user1);
        token0.approve(address(poolManager), type(uint256).max);
        vm.prank(user1);
        token1.approve(address(poolManager), type(uint256).max);
        vm.prank(user2);
        token0.approve(address(poolManager), type(uint256).max);
        vm.prank(user2);
        token1.approve(address(poolManager), type(uint256).max);
    }

    function testHookPermissions() public {
        Hooks.Permissions memory perms = hook.getHookPermissions();
        assertTrue(perms.beforeSwap);
        assertTrue(perms.afterSwap);
        assertFalse(perms.beforeInitialize);
        assertFalse(perms.beforeAddLiquidity);
        assertFalse(perms.beforeRemoveLiquidity);
    }

    function testDirectSwapReverts() public {
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: 100e18,
            sqrtPriceLimitX96: 0
        });
        
        vm.prank(user1);
        vm.expectRevert(ContinuumSwapHook.DirectSwapNotAllowed.selector);
        hook.beforeSwap(user1, testPoolKey, params, "");
    }

    function testExecuteTickAsRelayer() public {
        // Create swap orders
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](2);
        
        swaps[0] = OrderStructs.OrderedSwap({
            user: user1,
            poolKey: testPoolKey,
            params: IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 100e18,
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 1,
            signature: ""
        });
        
        swaps[1] = OrderStructs.OrderedSwap({
            user: user2,
            poolKey: testPoolKey,
            params: IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 50e18,
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 2,
            signature: ""
        });
        
        // Create VDF proof
        bytes32 batchHash = verifier.computeBatchHash(swaps);
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), batchHash),
            output: abi.encodePacked(keccak256("output1")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        // Execute tick as relayer
        vm.prank(relayer);
        hook.executeTick(1, swaps, proof, bytes32(0));
        
        // Verify tick was executed
        assertTrue(verifier.isTickExecuted(1));
        assertEq(hook.totalSwapsExecuted(), 2);
    }

    function testExecuteTickUnauthorizedRelayer() public {
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](1);
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), keccak256("batch")),
            output: abi.encodePacked(keccak256("output")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        vm.prank(user1);
        vm.expectRevert(ContinuumSwapHook.UnauthorizedRelayer.selector);
        hook.executeTick(1, swaps, proof, bytes32(0));
    }

    function testExecuteTickAlreadyExecuted() public {
        // Execute tick once
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](0);
        bytes32 batchHash = verifier.computeBatchHash(swaps);
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), batchHash),
            output: abi.encodePacked(keccak256("output")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        vm.prank(relayer);
        hook.executeTick(1, swaps, proof, bytes32(0));
        
        // Try to execute again
        vm.prank(relayer);
        vm.expectRevert(ContinuumVerifier.TickAlreadyExecuted.selector);
        hook.executeTick(1, swaps, proof, bytes32(0));
    }

    function testExecuteTickDeadlineExceeded() public {
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](1);
        
        swaps[0] = OrderStructs.OrderedSwap({
            user: user1,
            poolKey: testPoolKey,
            params: IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 100e18,
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp - 1, // Expired deadline
            sequenceNumber: 1,
            signature: ""
        });
        
        bytes32 batchHash = verifier.computeBatchHash(swaps);
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), batchHash),
            output: abi.encodePacked(keccak256("output")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        vm.prank(relayer);
        vm.expectRevert(ContinuumSwapHook.DeadlineExceeded.selector);
        hook.executeTick(1, swaps, proof, bytes32(0));
    }

    function testExecuteTickTooManySwaps() public {
        uint256 maxSwaps = hook.MAX_SWAPS_PER_TICK();
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](maxSwaps + 1);
        
        vm.prank(relayer);
        vm.expectRevert(ContinuumSwapHook.TooManySwaps.selector);
        OrderStructs.VdfProof memory emptyProof = OrderStructs.VdfProof({
            input: new bytes(0),
            output: new bytes(0),
            proof: new bytes(0),
            iterations: 0
        });
        hook.executeTick(1, swaps, emptyProof, bytes32(0));
    }

    function testOrderExecutionTracking() public {
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](1);
        
        swaps[0] = OrderStructs.OrderedSwap({
            user: user1,
            poolKey: testPoolKey,
            params: IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 100e18,
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 1,
            signature: ""
        });
        
        bytes32 orderId = keccak256(abi.encode(
            swaps[0].user,
            swaps[0].poolKey,
            swaps[0].params,
            swaps[0].deadline,
            swaps[0].sequenceNumber
        ));
        
        assertFalse(hook.isOrderExecuted(orderId));
        
        bytes32 batchHash = verifier.computeBatchHash(swaps);
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), batchHash),
            output: abi.encodePacked(keccak256("output")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        vm.prank(relayer);
        hook.executeTick(1, swaps, proof, bytes32(0));
        
        assertTrue(hook.isOrderExecuted(orderId));
    }

    function testRelayerAuthorization() public {
        address newRelayer = address(0x4);
        
        assertFalse(hook.authorizedRelayers(newRelayer));
        
        hook.authorizeRelayer(newRelayer, true);
        assertTrue(hook.authorizedRelayers(newRelayer));
        
        hook.authorizeRelayer(newRelayer, false);
        assertFalse(hook.authorizedRelayers(newRelayer));
    }

    function testGetExecutedTick() public {
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](1);
        
        swaps[0] = OrderStructs.OrderedSwap({
            user: user1,
            poolKey: testPoolKey,
            params: IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 100e18,
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 1,
            signature: ""
        });
        
        bytes32 batchHash = verifier.computeBatchHash(swaps);
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), batchHash),
            output: abi.encodePacked(keccak256("output")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        vm.prank(relayer);
        hook.executeTick(1, swaps, proof, bytes32(0));
        
        OrderStructs.ContinuumTick memory tick = hook.getExecutedTick(1);
        assertEq(tick.tickNumber, 1);
        assertEq(tick.swaps.length, 1);
        assertEq(tick.batchHash, batchHash);
        assertEq(tick.previousOutput, bytes32(0));
    }

    function testSequentialTickExecution() public {
        // Execute tick 1
        OrderStructs.OrderedSwap[] memory swaps1 = new OrderStructs.OrderedSwap[](0);
        bytes32 batchHash1 = verifier.computeBatchHash(swaps1);
        OrderStructs.VdfProof memory proof1 = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), batchHash1),
            output: abi.encodePacked(keccak256("output1")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        vm.prank(relayer);
        hook.executeTick(1, swaps1, proof1, bytes32(0));
        
        // Execute tick 2
        bytes32 previousOutput = keccak256(proof1.output);
        OrderStructs.OrderedSwap[] memory swaps2 = new OrderStructs.OrderedSwap[](0);
        bytes32 batchHash2 = verifier.computeBatchHash(swaps2);
        OrderStructs.VdfProof memory proof2 = OrderStructs.VdfProof({
            input: abi.encodePacked(previousOutput, batchHash2),
            output: abi.encodePacked(keccak256("output2")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        vm.prank(relayer);
        hook.executeTick(2, swaps2, proof2, previousOutput);
        
        assertEq(verifier.lastVerifiedTick(), 2);
    }
}