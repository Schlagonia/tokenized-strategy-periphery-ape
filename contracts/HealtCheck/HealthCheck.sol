// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

/**
 *   @title Health Check
 *   @author Yearn.finance
 *   @notice This contract can be inherited by any Yearn
 *   V3 strategy wishing to implement a health check during
 *   the `report` function in order to prevent any unexpected
 *   behavior from being permanently recorded.
 *
 *   A strategist simply needs to inherit this contract. Set
 *   the limit ratios to the desired amounts and then call
 *   `require(_executeHealthCheck(...), "!healthcheck)` during
 *   the  `_totalInvested()` execution. If the profit or loss
 *   that would be recorded is outside the acceptable bounds
 *   the tx will revert.
 *
 *   The healthcheck does not prevent a strategy from reporting
 *   losses, but rather can make sure manual intervention is
 *   needed before reporting an unexpected loss. Strategists
 *   should build in a method to manually turn off the health
 *   check or increase the limit ratios so that the strategy is
 *   able to report eventually.
 */
contract HealthCheck {
    uint256 constant MAX_BPS = 10_000;

    // Default profit limit to 100%
    uint256 public profitLimitRatio = 10_000;

    // Defaults loss limti to 0.
    uint256 public lossLimitRatio;

    /**
     * @dev Can be used to set the profit limit ratio. Denominated
     * in basis points. I.E. 1_000 == 10%.
     * @param _profitLimitRatio The mew profit limit ratio.
     */
    function _setProfitLimitRatio(uint256 _profitLimitRatio) internal {
        require(_profitLimitRatio < MAX_BPS, "!profit limit");
        profitLimitRatio = _profitLimitRatio;
    }

    /**
     * @dev Can be used to set the loss limit ratio. Denominated
     * in basis points. I.E. 1_000 == 10%.
     * @param _lossLimitRatio The new loss limit ratio.
     */
    function _setlossLimitRatio(uint256 _lossLimitRatio) internal {
        require(_lossLimitRatio < MAX_BPS, "!loss limit");
        lossLimitRatio = _lossLimitRatio;
    }

    /**
     * @dev To be called during a report to make sure the profit
     * or loss being recorded is within the acceptable bound.
     *
     * Strategies using this healthcheck should implement either
     * a way to bypass the check or manually up the limits if needed.
     * Otherwise this could prevent reports from ever recording
     * properly.
     *
     * @param _totalInvested The amount that will be returned during `totalInvested()`.
     * @param _totalAssets The amount returned from `TokenizedStrategy.totalAssets()`.
     */
     // TODO: call the contract to get totalAssets?
    function _executHealthCheck(
        uint256 _totalInvested,
        uint256 _totalAssets
    ) internal view returns (bool) {
        if (_totalInvested > _totalAssets) {
            return
                !((_totalInvested - _totalAssets) >
                    (_totalAssets * profitLimitRatio) / MAX_BPS);
        } else if (_totalAssets > _totalInvested) {
            return
                !(_totalInvested - _totalInvested >
                    ((_totalAssets * lossLimitRatio) / MAX_BPS));
        }

        // Nothing to check
        return true;
    }
}
