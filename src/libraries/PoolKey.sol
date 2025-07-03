// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Currency} from "./Currency.sol";
import {IHooks} from "../interfaces/IHooks.sol";

struct PoolKey {
    Currency currency0;
    Currency currency1;
    uint24 fee;
    int24 tickSpacing;
    IHooks hooks;
}