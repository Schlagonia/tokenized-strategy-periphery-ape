// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

contract HealthCheck {
    // Default Settings for all strategies
    uint256 constant MAX_BPS = 10_000;
    uint256 public profitLimitRatio;
    uint256 public lossLimitRatio;

    constructor() {
        profitLimitRatio = 300;
        lossLimitRatio = 100;
    }

    function setProfitLimitRatio(uint256 _profitLimitRatio) external {
        require(_profitLimitRatio < MAX_BPS);
        profitLimitRatio = _profitLimitRatio;
    }

    function setlossLimitRatio(uint256 _lossLimitRatio) external {
        require(_lossLimitRatio < MAX_BPS);
        lossLimitRatio = _lossLimitRatio;
    }

    function _executeDefaultCheck(
        uint256 _profit,
        uint256 _loss,
        uint256 _totalDebt
    ) internal view returns (bool) {
        uint256 _profitLimitRatio = profitLimitRatio;
        uint256 _lossLimitRatio = lossLimitRatio;

        if (_profit > ((_totalDebt * _profitLimitRatio) / MAX_BPS)) {
            return false;
        }
        if (_loss > ((_totalDebt * _lossLimitRatio) / MAX_BPS)) {
            return false;
        }
        // health checks pass
        return true;
    }
}
