// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

import {UniswapV3Swapper} from "../swaps/UniswapV3Swapper.sol";

contract MockUniswapV3Swapper is UniswapV3Swapper {
    function setMinAmountToSell(uint256 _minAmountToSell) external {
        minAmountToSell = _minAmountToSell;
    }

    function setRouter(address _router) external {
        router = _router;
    }

    function setBase(address _base) external {
        base = _base;
    }

    function setUniFees(
        address _token0,
        address _token1,
        uint24 _fee
    ) external {
        _setUniFees(_token0, _token1, _fee);
    }

    function swapFrom(
        address _from,
        address _to,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) external returns (uint256) {
        return _swapFrom(_from, _to, _amountIn, _minAmountOut);
    }

    function swapTo(
        address _from,
        address _to,
        uint256 _amountTo,
        uint256 _maxAmountFrom
    ) external returns (uint256) {
        return _swapTo(_from, _to, _amountTo, _maxAmountFrom);
    }
}
