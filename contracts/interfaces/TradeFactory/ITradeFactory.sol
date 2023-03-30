// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

interface ITradeFactory {
    function enable(address, address) external;

    function grantRole(bytes32 role, address account) external;

    function STRATEGY() external view returns (bytes32);
}
