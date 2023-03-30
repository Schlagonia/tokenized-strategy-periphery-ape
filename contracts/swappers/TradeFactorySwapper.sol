// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ITradeFactory} from "../interfaces/TradeFactory/ITradeFactory.sol";

contract TradeFactorySwapper {
    using SafeERC20 for ERC20;
    
    address private _tadeFactory;

    address[] public rewardTokens;

    // We use a getter so trade factory can only be set through the
    // proper functions to avoid issues.
    function tradeFactory() public view returns (address) {
        return _tradeFactory;
    }

    function _addTokens(address[] memory _from, address[] memory _to) internal {
        for(uint256 i; i < _from.length; ++i) {
            _addToken(_from[i], _to[i]);
        }
    }

    function _addToken(address _tokenFrom, address _tokenTo) internal {
        if(_tradeFactory != address(0)) {
            ERC20(token).safeApprove(_tradeFactory, type(uint256).max);

            ITradeFactory(_tradeFactory).enable(_tokenFrom, _tokenTo);
        }

        rewardTokens.push(_tokenFrom);
    }

    function _removeToken(address _token) internal {
        address[] memory _rewardTokens = rewardTokens;
        for(uint256 i; i < _rewardTokens.length; ++i) {
            if(_rewardTokens[i] == _token) {
                if (i != _rewardTokens.length - 1) {
                    // if it isn't the last token, swap with the last one/
                    _rewardTokens[i] = _rewardTokens[_rewardTokens.length - 1];
                }
                rewardTokens = _rewardTokens;
                rewardTokens.pop();
            }
        }
    }

    function _removeRewardTokens() internal {
        delete rewardTokens;
    }

    function _setTradeFactory(address _tradeFactory_, address _tokenTo) internal {
        if (_tradeFactory != address(0)) {
            _removeTradeFactoryPermissions();
        }

        address[] memory _rewardTokens = rewardTokens;
        ITradeFactory tf = ITradeFactory(_tradeFactory_);
        //We only need to set trade factory for non aura/bal tokens
        for(uint256 i; i < _rewardTokens.length; ++i) {
            address token = rewardTokens[i];
        
            IERC20(token).safeApprove(_tradeFactory_, type(uint256).max);

            tf.enable(token, _tokenTo);
        }

        _tradeFactory = _tradeFactory_;
    }

    function _removeTradeFactoryPermissions() internal {
        address[] memory _rewardTokens = rewardTokens;
        for(uint256 i; i < _rewardTokens.length; ++i) {
        
            ERC20(_rewardTokens[i]).safeApprove(_tradeFactory, 0);
        }
        
        _tradeFactory = address(0);
    }

    // Used for TradeFactory to claim rewards
    function claimRewards() external {
        require(msg.sender == _tradeFactory, "!authorized");            
        _claimRewards();
    }

    // Need to be overridden to claim rewards mid report cycles.
    function _claimRewards internal virtual;
}