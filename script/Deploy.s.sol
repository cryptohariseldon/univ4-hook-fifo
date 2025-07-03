// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/ContinuumSwapHook.sol";
import "../src/ContinuumVerifier.sol";
import "../test/mocks/MockPoolManager.sol";
import "../test/mocks/MockERC20.sol";

contract DeployScript is Script {
    // Deployed contract addresses
    ContinuumVerifier public verifier;
    ContinuumSwapHook public hook;
    MockPoolManager public poolManager;
    MockERC20 public usdc;
    MockERC20 public weth;
    
    // Test addresses
    address public relayer;
    address public alice;
    address public bob;
    
    function run() public {
        // Get deployment private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Derive addresses
        relayer = vm.addr(deployerPrivateKey);
        alice = address(0x1111111111111111111111111111111111111111);
        bob = address(0x2222222222222222222222222222222222222222);
        
        console.log("Deployer/Relayer:", relayer);
        console.log("Alice:", alice);
        console.log("Bob:", bob);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock tokens
        console.log("\nDeploying mock tokens...");
        usdc = new MockERC20("USD Coin", "USDC");
        weth = new MockERC20("Wrapped Ether", "WETH");
        console.log("USDC deployed at:", address(usdc));
        console.log("WETH deployed at:", address(weth));
        
        // Deploy mock pool manager
        console.log("\nDeploying mock pool manager...");
        poolManager = new MockPoolManager();
        console.log("Pool Manager deployed at:", address(poolManager));
        
        // Deploy Continuum contracts
        console.log("\nDeploying Continuum contracts...");
        verifier = new ContinuumVerifier();
        console.log("Verifier deployed at:", address(verifier));
        
        hook = new ContinuumSwapHook(IPoolManager(address(poolManager)), verifier);
        console.log("Hook deployed at:", address(hook));
        
        // Mint tokens to test addresses
        console.log("\nMinting tokens...");
        usdc.mint(alice, 10000e18);
        usdc.mint(bob, 10000e18);
        weth.mint(alice, 10e18);
        weth.mint(bob, 10e18);
        console.log("Minted 10,000 USDC and 10 WETH to Alice");
        console.log("Minted 10,000 USDC and 10 WETH to Bob");
        
        // Fund pool manager for swaps
        usdc.mint(address(poolManager), 100000e18);
        weth.mint(address(poolManager), 100e18);
        console.log("Funded pool manager with liquidity");
        
        vm.stopBroadcast();
        
        // Save deployment info
        console.log("\n=== Deployment Summary ===");
        console.log("Network: Sepolia Testnet");
        console.log("USDC:", address(usdc));
        console.log("WETH:", address(weth));
        console.log("Pool Manager:", address(poolManager));
        console.log("Verifier:", address(verifier));
        console.log("Hook:", address(hook));
        console.log("========================\n");
        
        // Write deployment addresses to file
        _saveDeploymentAddresses();
    }
    
    function _saveDeploymentAddresses() internal {
        string memory deploymentInfo = string(abi.encodePacked(
            "{\n",
            '  "network": "sepolia",\n',
            '  "contracts": {\n',
            '    "usdc": "', vm.toString(address(usdc)), '",\n',
            '    "weth": "', vm.toString(address(weth)), '",\n',
            '    "poolManager": "', vm.toString(address(poolManager)), '",\n',
            '    "verifier": "', vm.toString(address(verifier)), '",\n',
            '    "hook": "', vm.toString(address(hook)), '"\n',
            '  },\n',
            '  "addresses": {\n',
            '    "relayer": "', vm.toString(relayer), '",\n',
            '    "alice": "', vm.toString(alice), '",\n',
            '    "bob": "', vm.toString(bob), '"\n',
            '  }\n',
            "}\n"
        ));
        
        vm.writeFile("deployment-addresses.json", deploymentInfo);
    }
}