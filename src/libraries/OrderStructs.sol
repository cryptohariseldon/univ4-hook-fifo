// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "./PoolKey.sol";
import {IPoolManager} from "../interfaces/IPoolManager.sol";

library OrderStructs {
    struct OrderedSwap {
        address user;
        PoolKey poolKey;
        IPoolManager.SwapParams params;
        uint256 deadline;
        uint256 sequenceNumber;
        bytes signature;
    }

    struct VdfProof {
        bytes input;
        bytes output;
        bytes proof;
        uint256 iterations;
    }

    struct ContinuumTick {
        uint256 tickNumber;
        VdfProof vdfProof;
        OrderedSwap[] swaps;
        bytes32 batchHash;
        uint256 timestamp;
        bytes32 previousOutput;
    }

    struct SwapOrder {
        bytes32 orderId;
        address user;
        PoolKey poolKey;
        IPoolManager.SwapParams params;
        uint256 deadline;
        uint256 nonce;
        uint256 minAmountOut;
    }

    struct ExecutionReceipt {
        uint256 tickNumber;
        uint256 sequenceNumber;
        bytes32 txHash;
        uint256 executedAt;
        int256 amountSpecified;
        int256 amountReceived;
    }
}