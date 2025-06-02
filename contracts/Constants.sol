// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/// @dev Address used to identify a multi delegate call in a diamond cut.
address constant MULTI_INIT_ADDRESS = 0xD1a302d1A302d1A302d1A302d1A302D1A302D1a3;

/// @dev Default admin role value.
uint8 constant ROLE_SUPER_ADMIN = 0;

uint8 constant ROLE_OPERATOR_MANAGER = 1;

uint8 constant ROLE_BURNER = 2;

uint8 constant ROLE_MINTER = 3;

uint8 constant ROLE_MATCH_ORDER = 4;

uint8 constant ROLE_MARKET_MANAGER = 5;

uint8 constant ROLE_ADMIN = 6;

uint8 constant ROLE_REWARD_CLAIMER = 7;
