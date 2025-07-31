// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ContinuumSwapHook} from "../src/ContinuumSwapHook.sol";
import {ContinuumVerifier} from "../src/ContinuumVerifier.sol";
import {SimpleMockPoolManager} from "../test/mocks/SimpleMockPoolManager.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {OrderStructs} from "../src/libraries/OrderStructs.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

contract TestSepoliaSwapsScript is Script {
    using OrderStructs for *;
    
    // Deployed addresses on Sepolia
    address constant VERIFIER = 0xa032C297090C4064dfc082Fb2da8Dd864D688dDF;
    address constant HOOK = 0xC8Cb365a66fb128A1C5fe756aFB918b346125a33;
    address constant POOL_MANAGER = 0x103E10e28229FCD87d2714f3e6016450B3C57C7c;
    address constant USDC = 0x069A6C16bB614Ca8b3eAb3C3eE4E5d79e4CAa86E;
    address constant WETH = 0x66a4F569E12C582EfDbaDE149AA49007143c90B1;
    
    // Test users
    address constant ALICE = 0x1111111111111111111111111111111111111111;
    address constant BOB = 0x2222222222222222222222222222222222222222;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address relayer = vm.addr(deployerPrivateKey);
        
        console.log("=== Testing Continuum Swaps on Sepolia ===");
        console.log("Relayer:", relayer);
        console.log("");
        
        // Load contracts
        ContinuumVerifier verifier = ContinuumVerifier(VERIFIER);
        ContinuumSwapHook hook = ContinuumSwapHook(HOOK);
        SimpleMockPoolManager poolManager = SimpleMockPoolManager(POOL_MANAGER);
        MockERC20 usdc = MockERC20(USDC);
        MockERC20 weth = MockERC20(WETH);
        
        // Check balances
        console.log("Initial Balances:");
        console.log("  Alice USDC:", usdc.balanceOf(ALICE) / 1e18);
        console.log("  Alice WETH:", weth.balanceOf(ALICE) / 1e18);
        console.log("  Bob USDC:", usdc.balanceOf(BOB) / 1e18);
        console.log("  Bob WETH:", weth.balanceOf(BOB) / 1e18);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Create pool key
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(USDC),
            currency1: Currency.wrap(WETH),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(HOOK)
        });
        
        // Create test swaps
        console.log("Creating swap orders...");
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](2);
        
        // Alice swaps 1000 USDC for WETH
        swaps[0] = OrderStructs.OrderedSwap({
            user: ALICE,
            poolKey: poolKey,
            params: IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 1000e18,
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 1,
            signature: ""
        });
        
        // Bob swaps 1 WETH for USDC
        swaps[1] = OrderStructs.OrderedSwap({
            user: BOB,
            poolKey: poolKey,
            params: IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: 1e18,
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 2,
            signature: ""
        });
        
        console.log("  Order 1: Alice swaps 1000 USDC for WETH");
        console.log("  Order 2: Bob swaps 1 WETH for USDC");
        console.log("");
        
        // Create VDF proof (mock)
        console.log("Creating VDF proof...");
        uint256 tickNumber = 1;
        bytes32 previousOutput = bytes32(0);
        bytes32 batchHash = verifier.computeBatchHash(swaps);
        
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(previousOutput, batchHash),
            output: abi.encodePacked(keccak256(abi.encodePacked("sepolia_tick_1"))),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        // Execute tick
        console.log("Executing tick through Continuum...");
        try hook.executeTick(tickNumber, swaps, proof, previousOutput) {
            console.log("  Tick executed successfully!");
        } catch Error(string memory reason) {
            console.log("  Execution failed:", reason);
        } catch {
            console.log("  Execution failed with unknown error");
        }
        
        vm.stopBroadcast();
        
        // Check final balances
        console.log("");
        console.log("Final Balances:");
        console.log("  Alice USDC:", usdc.balanceOf(ALICE) / 1e18);
        console.log("  Alice WETH:", weth.balanceOf(ALICE) / 1e18);
        console.log("  Bob USDC:", usdc.balanceOf(BOB) / 1e18);
        console.log("  Bob WETH:", weth.balanceOf(BOB) / 1e18);
        
        // Check execution status
        console.log("");
        console.log("Execution Status:");
        console.log("  Tick executed:", verifier.isTickExecuted(tickNumber));
        console.log("  Total swaps:", hook.totalSwapsExecuted());
        
        console.log("");
        console.log("=== Test Complete ===");
        console.log("View on Etherscan:");
        console.log("  https://sepolia.etherscan.io/address/", HOOK);
    }
}