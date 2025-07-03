// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ContinuumSwapHook} from "../src/ContinuumSwapHook.sol";
import {ContinuumVerifier} from "../src/ContinuumVerifier.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

contract DeploySepoliaV4Script is Script {
    // Base Sepolia UNI-v4 addresses
    address constant BASE_SEPOLIA_POOL_MANAGER = 0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829;
    address constant BASE_SEPOLIA_POSITION_MANAGER = 0x1a9062E4FAe8ab7580616B288e2BCBD10F8923B5;
    
    // Sepolia testnet addresses (if available)
    address constant SEPOLIA_POOL_MANAGER = address(0); // Update when available
    
    // Test tokens on Base Sepolia
    address constant BASE_SEPOLIA_USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant BASE_SEPOLIA_WETH = 0x4200000000000000000000000000000000000006;
    
    ContinuumVerifier public verifier;
    ContinuumSwapHook public hook;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Determine which network we're on
        string memory network = "unknown";
        address poolManager;
        
        if (block.chainid == 84532) {
            network = "Base Sepolia";
            poolManager = BASE_SEPOLIA_POOL_MANAGER;
        } else if (block.chainid == 11155111) {
            network = "Sepolia";
            poolManager = SEPOLIA_POOL_MANAGER;
            require(poolManager != address(0), "Sepolia pool manager not set");
        } else {
            revert("Unsupported network");
        }
        
        console.log("=== Deploying Continuum Hook for UNI-v4 ===");
        console.log("Network:", network);
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("Using Pool Manager:", poolManager);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Continuum Verifier
        console.log("1. Deploying Continuum Verifier...");
        verifier = new ContinuumVerifier();
        console.log("   Verifier deployed at:", address(verifier));
        
        // Deploy hook with CREATE2 for deterministic address
        console.log("");
        console.log("2. Finding valid hook address with CREATE2...");
        (bytes32 salt, address expectedHookAddress) = findValidHookAddress(poolManager, address(verifier), deployer);
        console.log("   Found valid salt:", uint256(salt));
        console.log("   Expected hook address:", expectedHookAddress);
        
        // Deploy the hook
        console.log("");
        console.log("3. Deploying Continuum Hook...");
        hook = deployHookWithCreate2(salt, poolManager, address(verifier));
        console.log("   Hook deployed at:", address(hook));
        require(address(hook) == expectedHookAddress, "Hook address mismatch");
        
        // Verify permissions
        console.log("");
        console.log("4. Verifying hook permissions...");
        Hooks.Permissions memory perms = hook.getHookPermissions();
        console.log("   beforeSwap:", perms.beforeSwap);
        console.log("   afterSwap:", perms.afterSwap);
        
        vm.stopBroadcast();
        
        // Save deployment info
        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("Verifier:", address(verifier));
        console.log("Hook:", address(hook));
        console.log("");
        console.log("Next steps:");
        console.log("1. Create a pool with this hook attached");
        console.log("2. Add liquidity to the pool");
        console.log("3. Submit swaps through Continuum");
        
        // Write deployment addresses
        _saveDeploymentAddresses(network);
    }
    
    function findValidHookAddress(
        address poolManager,
        address verifier,
        address deployer
    ) internal pure returns (bytes32 salt, address hookAddress) {
        // Required permissions: beforeSwap and afterSwap
        uint160 requiredPermissions = Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG;
        
        for (uint256 i = 0; i < 100000; i++) {
            salt = bytes32(i);
            hookAddress = computeCreate2Address(salt, poolManager, verifier, deployer);
            
            if (isValidHookAddress(hookAddress, requiredPermissions)) {
                return (salt, hookAddress);
            }
        }
        
        revert("Could not find valid hook address");
    }
    
    function computeCreate2Address(
        bytes32 salt,
        address poolManager,
        address verifier,
        address deployer
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
    
    function isValidHookAddress(address hookAddress, uint160 requiredPermissions) internal pure returns (bool) {
        uint160 addr = uint160(hookAddress);
        
        // Check if required permission bits are set
        return (addr & requiredPermissions) == requiredPermissions;
    }
    
    function deployHookWithCreate2(
        bytes32 salt,
        address poolManager,
        address verifier
    ) internal returns (ContinuumSwapHook) {
        bytes memory bytecode = abi.encodePacked(
            type(ContinuumSwapHook).creationCode,
            abi.encode(poolManager, verifier)
        );
        
        address hook;
        assembly {
            hook := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        
        require(hook != address(0), "Hook deployment failed");
        return ContinuumSwapHook(hook);
    }
    
    function _saveDeploymentAddresses(string memory network) internal {
        string memory json = string(abi.encodePacked(
            '{\n',
            '  "network": "', network, '",\n',
            '  "chainId": ', vm.toString(block.chainid), ',\n',
            '  "contracts": {\n',
            '    "verifier": "', vm.toString(address(verifier)), '",\n',
            '    "hook": "', vm.toString(address(hook)), '"\n',
            '  },\n',
            '  "timestamp": ', vm.toString(block.timestamp), '\n',
            '}\n'
        ));
        
        string memory filename = string(abi.encodePacked("deployment-", network, ".json"));
        vm.writeFile(filename, json);
        console.log("Deployment info saved to:", filename);
    }
}