// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/ContinuumVerifier.sol";
import "../src/libraries/OrderStructs.sol";

contract ContinuumVerifierTest is Test {
    using OrderStructs for *;

    ContinuumVerifier public verifier;
    
    function setUp() public {
        verifier = new ContinuumVerifier();
    }

    function testInitialState() public {
        assertEq(verifier.lastVerifiedTick(), 0);
        assertEq(verifier.lastVerifiedOutput(), bytes32(0));
    }

    function testVerifyFirstTick() public {
        uint256 tickNumber = 1;
        bytes32 batchHash = keccak256("batch1");
        bytes32 previousOutput = bytes32(0);
        
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(previousOutput, batchHash),
            output: abi.encodePacked(keccak256("output1")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        bool success = verifier.verifyAndStoreTick(tickNumber, proof, batchHash, previousOutput);
        assertTrue(success);
        
        assertEq(verifier.lastVerifiedTick(), tickNumber);
        assertEq(verifier.lastVerifiedOutput(), keccak256(proof.output));
    }

    function testVerifySequentialTicks() public {
        // Verify first tick
        OrderStructs.VdfProof memory proof1 = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), keccak256("batch1")),
            output: abi.encodePacked(keccak256("output1")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        verifier.verifyAndStoreTick(1, proof1, keccak256("batch1"), bytes32(0));
        
        // Verify second tick
        bytes32 previousOutput = keccak256(proof1.output);
        OrderStructs.VdfProof memory proof2 = OrderStructs.VdfProof({
            input: abi.encodePacked(previousOutput, keccak256("batch2")),
            output: abi.encodePacked(keccak256("output2")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        bool success = verifier.verifyAndStoreTick(2, proof2, keccak256("batch2"), previousOutput);
        assertTrue(success);
        
        assertEq(verifier.lastVerifiedTick(), 2);
    }

    function testRevertOnInvalidSequence() public {
        // Try to verify tick 2 without tick 1
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), keccak256("batch")),
            output: abi.encodePacked(keccak256("output")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        vm.expectRevert(ContinuumVerifier.InvalidTickSequence.selector);
        verifier.verifyAndStoreTick(2, proof, keccak256("batch"), bytes32(0));
    }

    function testRevertOnWrongPreviousOutput() public {
        // Verify first tick
        OrderStructs.VdfProof memory proof1 = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), keccak256("batch1")),
            output: abi.encodePacked(keccak256("output1")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        verifier.verifyAndStoreTick(1, proof1, keccak256("batch1"), bytes32(0));
        
        // Try to verify second tick with wrong previous output
        OrderStructs.VdfProof memory proof2 = OrderStructs.VdfProof({
            input: abi.encodePacked(keccak256("wrong"), keccak256("batch2")),
            output: abi.encodePacked(keccak256("output2")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        vm.expectRevert(ContinuumVerifier.InvalidTickSequence.selector);
        verifier.verifyAndStoreTick(2, proof2, keccak256("batch2"), keccak256("wrong"));
    }

    function testMarkTickExecuted() public {
        // Verify a tick first
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), keccak256("batch")),
            output: abi.encodePacked(keccak256("output")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        verifier.verifyAndStoreTick(1, proof, keccak256("batch"), bytes32(0));
        
        // Mark it as executed
        assertFalse(verifier.isTickExecuted(1));
        verifier.markTickExecuted(1);
        assertTrue(verifier.isTickExecuted(1));
    }

    function testRevertOnDoubleExecution() public {
        // Verify and execute a tick
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), keccak256("batch")),
            output: abi.encodePacked(keccak256("output")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        verifier.verifyAndStoreTick(1, proof, keccak256("batch"), bytes32(0));
        verifier.markTickExecuted(1);
        
        // Try to execute again
        vm.expectRevert(ContinuumVerifier.TickAlreadyExecuted.selector);
        verifier.markTickExecuted(1);
    }

    function testComputeBatchHash() public {
        OrderStructs.OrderedSwap[] memory swaps = new OrderStructs.OrderedSwap[](2);
        
        // Create dummy swaps
        swaps[0].user = address(0x1);
        swaps[0].sequenceNumber = 1;
        swaps[1].user = address(0x2);
        swaps[1].sequenceNumber = 2;
        
        bytes32 hash1 = verifier.computeBatchHash(swaps);
        bytes32 hash2 = verifier.computeBatchHash(swaps);
        
        // Same input should produce same hash
        assertEq(hash1, hash2);
        
        // Different input should produce different hash
        swaps[0].user = address(0x3);
        bytes32 hash3 = verifier.computeBatchHash(swaps);
        assertTrue(hash1 != hash3);
    }

    function testVerifyTickChain() public {
        // Genesis tick (0) should always pass
        assertTrue(verifier.verifyTickChain(0, bytes32(0), keccak256("batch")));
        
        // Verify first tick
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), keccak256("batch1")),
            output: abi.encodePacked(keccak256("output1")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        verifier.verifyAndStoreTick(1, proof, keccak256("batch1"), bytes32(0));
        
        // Check chain verification
        bytes32 output1 = keccak256(proof.output);
        assertTrue(verifier.verifyTickChain(2, output1, keccak256("batch2")));
        assertFalse(verifier.verifyTickChain(2, keccak256("wrong"), keccak256("batch2")));
    }

    function testInvalidProofIterations() public {
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: abi.encodePacked(bytes32(0), keccak256("batch")),
            output: abi.encodePacked(keccak256("output")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 26 // Wrong iteration count
        });
        
        vm.expectRevert(ContinuumVerifier.ProofVerificationFailed.selector);
        verifier.verifyAndStoreTick(1, proof, keccak256("batch"), bytes32(0));
    }

    function testEmptyProofComponents() public {
        OrderStructs.VdfProof memory proof = OrderStructs.VdfProof({
            input: "", // Empty input
            output: abi.encodePacked(keccak256("output")),
            proof: abi.encodePacked(uint256(1)),
            iterations: 27
        });
        
        vm.expectRevert(ContinuumVerifier.ProofVerificationFailed.selector);
        verifier.verifyAndStoreTick(1, proof, keccak256("batch"), bytes32(0));
    }
}