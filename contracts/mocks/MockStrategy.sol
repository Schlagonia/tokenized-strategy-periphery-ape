// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

import { ZeroExSwapper } from "../swappers/ZeroExSwapper.sol";

contract MockStrategy is ZeroExSwapper {
  address public keeper;
  address public want;

  bool private initialized;

  modifier onlyKeeper() {
    require(msg.sender == keeper, "Keeper only mock");
    _;
  }

  function initializeStrategy(address _want, address _zeroExRouter) external {
    require(!initialized, "Initialized");

    want = _want;
    keeper = msg.sender;

    // mock setup, sell crv for dai, sell cvx for usdc
    address[] memory rewards = new address[](2);
    rewards[0] = address(0xD533a949740bb3306d119CC777fa900bA034cd52); // crv
    rewards[1] = address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B); // cvx

    address[] memory rewardsTargets = new address[](2);
    rewardsTargets[0] = address(0x6B175474E89094C44Da98b954EedeAC495271d0F); // dai
    rewardsTargets[1] = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // usdc

    _initializeZeroExSwapper(rewards, rewardsTargets, _zeroExRouter);
    initialized = true;
  }

  // Example external implementations with access control //

  function setRewardToken(
    address rewardToken,
    address targetTokenForRewardToken
  ) external onlyKeeper {
    _setRewardToken(rewardToken, targetTokenForRewardToken);
  }

  function deleteRewardToken(address rewardToken) external onlyKeeper {
    _deleteRewardToken(rewardToken);
  }

  function swap(
    bytes calldata swapData,
    address rewardToken
  ) external onlyKeeper {
    _swap(swapData, rewardToken);
  }
}
