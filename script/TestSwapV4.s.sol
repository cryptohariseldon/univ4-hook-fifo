// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ContinuumSwapHook} from "../src/ContinuumSwapHook.sol";
import {ContinuumVerifier} from "../src/ContinuumVerifier.sol";
import {OrderStructs} from "../src/libraries/OrderStructs.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract TestSwapV4Script is Script {
    using OrderStructs for *;
    
    // Base Sepolia addresses
    address constant POOL_MANAGER = 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829;
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address relayer = vm.addr(deployerPrivateKey);
        
        // Load deployed contracts
        address verifierAddress = vm.envAddress("VERIFIER_ADDRESS");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        
        ContinuumVerifier verifier = ContinuumVerifier(verifierAddress);
        ContinuumSwapHook hook = ContinuumSwapHook(hookAddress);
        
        console.log("=== Testing Continuum Swap Execution ===");
        console.log("Relayer:", relayer);
        console.log("Verifier:", verifierAddress);
        console.log("Hook:", hookAddress);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Ensure relayer is authorized
        if (!hook.authorizedRelayers(relayer)) {
            console.log("Authorizing relayer...");
            hook.authorizeRelayer(relayer, true);
        }
        
        // Create test users
        address alice = address(0x1111111111111111111111111111111111111111);
        address bob = address(0x2222222222222222222222222222222222222222);
        
        // Fund test users (in production, users would already have funds)
        console.log("Preparing test users...");
        IERC20(USDC).transfer(alice, 1000e6); // 1000 USDC
        IERC20(WETH).transfer(bob, 1e18); // 1 WETH
        console.log("  Alice funded with 1000 USDC");
        console.log("  Bob funded with 1 WETH");
        
        // Create pool key
        (Currency currency0, Currency currency1) = sortCurrencies(
            Currency.wrap(USDC),
            Currency.wrap(WETH)
        );
        
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });
        
        // Create swap orders
        console.log("");
        console.log("Creating swap orders...");
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](2);
        
        // Alice swaps 100 USDC for WETH
        swaps[0] = OrderStructs.OrderedSwap({
            user: alice,
            poolKey: poolKey,
            params: IPoolManager.SwapParams({
                zeroForOne: Currency.unwrap(currency0) == USDC,
                amountSpecified: -100e6, // Negative for exact input
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 1,
            signature: ""
        });
        
        // Bob swaps 0.1 WETH for USDC
        swaps[1] = OrderStructs.OrderedSwap({
            user: bob,
            poolKey: poolKey,
            params: IPoolManager.SwapParams({
                zeroForOne: Currency.unwrap(currency0) == WETH,
                amountSpecified: -0.1e18, // Negative for exact input
                sqrtPriceLimitX96: 0
            }),
            deadline: block.timestamp + 1 hours,
            sequenceNumber: 2,
            signature: ""
        });
        
        console.log("  Order 1: Alice swaps 100 USDC for WETH");
        console.log("  Order 2: Bob swaps 0.1 WETH for USDC");
        
        // Create VDF proof (mock for testnet)
        console.log("");
        console.log("Creating VDF proof...");
        uint256 tickNumber = 1;
        bytes32 previousOutput = bytes32(0); // First tick
        bytes32 batchHash = verifier.computeBatchHash(swaps);
        
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(previousOutput, batchHash),
            output: abi.encodePacked(keccak256(abi.encodePacked("test_tick_", tickNumber))),
            proof: abi.encodePacked(uint256(1)), // Mock proof
            iterations: 27
        });
        
        // Execute tick
        console.log("Executing tick...");
        hook.executeTick(tickNumber, swaps, proof, previousOutput);
        console.log("Tick executed successfully!");
        
        // Check results
        console.log("");
        console.log("Checking balances...");
        uint256 aliceWeth = IERC20(WETH).balanceOf(alice);
        uint256 bobUsdc = IERC20(USDC).balanceOf(bob);
        console.log("  Alice WETH balance:", aliceWeth);
        console.log("  Bob USDC balance:", bobUsdc);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== Test Complete ===");
        console.log("Successfully executed Continuum-ordered swaps on UNI-v4!");
    }
    
    function sortCurrencies(Currency a, Currency b) internal pure returns (Currency, Currency) {
        if (Currency.unwrap(a) < Currency.unwrap(b)) {
            return (a, b);
        } else {
            return (b, a);
        }
    }
}