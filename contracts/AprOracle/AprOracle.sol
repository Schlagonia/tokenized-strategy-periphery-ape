// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

import {IStrategy} from "../interfaces/IStrategy.sol";

interface IOracle {
    function aprAfterDebtChange(
        address _asset,
        int256 _delta
    ) external view returns (uint256);
}

contract AprOacle {
    mapping(address => address) public oracles;

    function getExpectedApr(
        address _strategy,
        int256 _debtChange
    ) public view returns (uint256) {
        address asset = IStrategy(_strategy).asset();
        address oracle = oracles[_strategy];

        // Will revert if a oracle is not set.
        return IOracle(oracle).aprAfterDebtChange(asset, _debtChange);
    }

    function weightedApr(address _strategy) external view returns (uint256) {
        return
            IStrategy(_strategy).totalAssets() * getExpectedApr(_strategy, 0);
    }

    function setOracle(address _strategy, address _oracle) external {
        require(msg.sender == IStrategy(_strategy).management(), "!authorized");

        oracles[_strategy] = _oracle;
    }
}
