// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {CurrencyLibrary} from "v4-core/types/Currency.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract InitializePoolV4Script is Script {
    // Base Sepolia addresses
    address constant POOL_MANAGER = 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829;
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    
    // Pool parameters
    uint24 constant POOL_FEE = 3000; // 0.3%
    int24 constant TICK_SPACING = 60;
    uint160 constant INITIAL_SQRT_PRICE = 79228162514264337593543950336; // 1:1 price
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Load hook address from deployment
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        
        console.log("=== Initializing UNI-v4 Pool with Continuum Hook ===");
        console.log("Deployer:", deployer);
        console.log("Hook Address:", hookAddress);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Sort tokens (required by UNI-v4)
        (Currency currency0, Currency currency1) = sortCurrencies(
            Currency.wrap(USDC),
            Currency.wrap(WETH)
        );
        
        // Create pool key
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(hookAddress)
        });
        
        console.log("Pool Configuration:");
        console.log("  Currency0:", Currency.unwrap(currency0));
        console.log("  Currency1:", Currency.unwrap(currency1));
        console.log("  Fee:", POOL_FEE);
        console.log("  Tick Spacing:", uint24(TICK_SPACING));
        console.log("");
        
        // Initialize pool
        console.log("Initializing pool...");
        int24 tick = IPoolManager(POOL_MANAGER).initialize(poolKey, INITIAL_SQRT_PRICE);
        console.log("Pool initialized at tick:", tick);
        
        // Add initial liquidity
        console.log("");
        console.log("Adding liquidity...");
        addLiquidity(poolKey, deployer);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== Pool Initialization Complete ===");
        console.log("Pool is ready for Continuum-ordered swaps!");
        
        // Save pool info
        _savePoolInfo(poolKey);
    }
    
    function sortCurrencies(Currency a, Currency b) internal pure returns (Currency, Currency) {
        if (Currency.unwrap(a) < Currency.unwrap(b)) {
            return (a, b);
        } else {
            return (b, a);
        }
    }
    
    function addLiquidity(PoolKey memory poolKey, address provider) internal {
        // Approve tokens
        IERC20(Currency.unwrap(poolKey.currency0)).approve(POOL_MANAGER, type(uint256).max);
        IERC20(Currency.unwrap(poolKey.currency1)).approve(POOL_MANAGER, type(uint256).max);
        
        // Add liquidity to a wide range
        IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
            tickLower: -887220, // Min tick for 60 spacing
            tickUpper: 887220,  // Max tick for 60 spacing
            liquidityDelta: 1000000000000000000, // 1e18
            salt: bytes32(0)
        });
        
        IPoolManager(POOL_MANAGER).modifyLiquidity(poolKey, params, "");
        console.log("Liquidity added successfully");
    }
    
    function _savePoolInfo(PoolKey memory poolKey) internal {
        string memory json = string(abi.encodePacked(
            '{\n',
            '  "pool": {\n',
            '    "currency0": "', vm.toString(Currency.unwrap(poolKey.currency0)), '",\n',
            '    "currency1": "', vm.toString(Currency.unwrap(poolKey.currency1)), '",\n',
            '    "fee": ', vm.toString(poolKey.fee), ',\n',
            '    "tickSpacing": ', vm.toString(uint256(int256(poolKey.tickSpacing))), ',\n',
            '    "hooks": "', vm.toString(address(poolKey.hooks)), '"\n',
            '  }\n',
            '}\n'
        ));
        
        vm.writeFile("pool-info.json", json);
        console.log("Pool info saved to pool-info.json");
    }
}