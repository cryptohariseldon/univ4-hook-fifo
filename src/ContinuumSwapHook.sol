// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "./interfaces/IHooks.sol";
import {IPoolManager} from "./interfaces/IPoolManager.sol";
import {PoolKey} from "./libraries/PoolKey.sol";
import {BalanceDelta} from "./libraries/BalanceDelta.sol";
import {Currency} from "./libraries/Currency.sol";
import {BeforeSwapDelta} from "./interfaces/IHooks.sol";
import {OrderStructs} from "./libraries/OrderStructs.sol";
import {ContinuumVerifier} from "./ContinuumVerifier.sol";
import {Hooks} from "./libraries/Hooks.sol";
import {BaseHook} from "./BaseHook.sol";

contract ContinuumSwapHook is BaseHook {
    using OrderStructs for *;
    using Hooks for IHooks;

    ContinuumVerifier public immutable verifier;
    IPoolManager public immutable poolManager;
    
    mapping(address => bool) public authorizedRelayers;
    mapping(bytes32 => bool) public executedOrders;
    mapping(uint256 => OrderStructs.ContinuumTick) public executedTicks;
    
    uint256 public constant MAX_SWAPS_PER_TICK = 100;
    uint256 public totalSwapsExecuted;
    
    event SwapExecuted(
        uint256 indexed tickNumber,
        uint256 indexed sequenceNumber,
        address indexed user,
        bytes32 orderId,
        int256 amountIn,
        int256 amountOut
    );
    
    event TickExecuted(uint256 indexed tickNumber, uint256 swapCount);
    event RelayerAuthorized(address indexed relayer, bool authorized);
    
    error UnauthorizedRelayer();
    error DirectSwapNotAllowed();
    error InvalidTickProof();
    error TickAlreadyExecuted();
    error OrderAlreadyExecuted();
    error DeadlineExceeded();
    error TooManySwaps();
    error InvalidSignature();

    modifier onlyRelayer() {
        if (!authorizedRelayers[msg.sender]) revert UnauthorizedRelayer();
        _;
    }

    constructor(IPoolManager _poolManager, ContinuumVerifier _verifier) {
        poolManager = _poolManager;
        verifier = _verifier;
        authorizedRelayers[msg.sender] = true;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        // Only allow swaps through executeTick function
        if (sender != address(this)) {
            revert DirectSwapNotAllowed();
        }
        
        return (BaseHook.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        // Hook data contains the original user and order details
        if (hookData.length > 0) {
            (address user, bytes32 orderId, uint256 tickNumber, uint256 sequenceNumber) = 
                abi.decode(hookData, (address, bytes32, uint256, uint256));
            
            emit SwapExecuted(
                tickNumber,
                sequenceNumber,
                user,
                orderId,
                params.amountSpecified,
                params.zeroForOne ? delta.amount1() : delta.amount0()
            );
        }
        
        return (BaseHook.afterSwap.selector, 0);
    }

    function executeTick(
        uint256 tickNumber,
        OrderStructs.OrderedSwap[] calldata swaps,
        OrderStructs.VdfProof calldata proof,
        bytes32 previousOutput
    ) external onlyRelayer {
        if (swaps.length > MAX_SWAPS_PER_TICK) revert TooManySwaps();
        if (verifier.isTickExecuted(tickNumber)) revert TickAlreadyExecuted();
        
        // Compute batch hash
        bytes32 batchHash = verifier.computeBatchHash(swaps);
        
        // Verify VDF proof
        if (!verifier.verifyAndStoreTick(tickNumber, proof, batchHash, previousOutput)) {
            revert InvalidTickProof();
        }
        
        // Execute swaps in order
        for (uint256 i = 0; i < swaps.length; i++) {
            _executeSwap(tickNumber, i, swaps[i]);
        }
        
        // Mark tick as executed
        verifier.markTickExecuted(tickNumber);
        
        // Store tick data
        executedTicks[tickNumber] = OrderStructs.ContinuumTick({
            tickNumber: tickNumber,
            vdfProof: proof,
            swaps: swaps,
            batchHash: batchHash,
            timestamp: block.timestamp,
            previousOutput: previousOutput
        });
        
        totalSwapsExecuted += swaps.length;
        emit TickExecuted(tickNumber, swaps.length);
    }

    function _executeSwap(
        uint256 tickNumber,
        uint256 index,
        OrderStructs.OrderedSwap calldata swap
    ) internal {
        // Check deadline
        if (block.timestamp > swap.deadline) revert DeadlineExceeded();
        
        // Verify signature
        bytes32 orderId = _verifySwapSignature(swap);
        if (executedOrders[orderId]) revert OrderAlreadyExecuted();
        
        // Mark order as executed
        executedOrders[orderId] = true;
        
        // Prepare hook data
        bytes memory hookData = abi.encode(swap.user, orderId, tickNumber, swap.sequenceNumber);
        
        // Execute swap through pool manager
        BalanceDelta delta = poolManager.swap(swap.poolKey, swap.params, hookData);
        
        // Handle token transfers
        _settleDeltas(swap.user, swap.poolKey, delta);
    }

    function _verifySwapSignature(OrderStructs.OrderedSwap calldata swap) internal pure returns (bytes32) {
        // Compute order hash
        bytes32 orderId = keccak256(abi.encode(
            swap.user,
            swap.poolKey,
            swap.params,
            swap.deadline,
            swap.sequenceNumber
        ));
        
        // TODO: Implement actual signature verification
        // For MVP, we'll skip signature verification
        // In production, verify swap.signature against orderId
        
        return orderId;
    }

    function _settleDeltas(
        address user,
        PoolKey calldata key,
        BalanceDelta delta
    ) internal {
        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();
        
        // For mock testing, we'll handle transfers directly
        // In production, this would use the pool manager's settlement logic
        
        if (amount0 < 0) {
            // User receives token0
            poolManager.take(key.currency0, user, uint128(-amount0));
        }
        
        if (amount1 < 0) {
            // User receives token1
            poolManager.take(key.currency1, user, uint128(-amount1));
        }
    }

    function authorizeRelayer(address relayer, bool authorized) external {
        // TODO: Add access control
        authorizedRelayers[relayer] = authorized;
        emit RelayerAuthorized(relayer, authorized);
    }

    function getExecutedTick(uint256 tickNumber) external view returns (OrderStructs.ContinuumTick memory) {
        return executedTicks[tickNumber];
    }

    function isOrderExecuted(bytes32 orderId) external view returns (bool) {
        return executedOrders[orderId];
    }
}