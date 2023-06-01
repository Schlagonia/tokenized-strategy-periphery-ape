// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 *   @title ZeroExSwapper
 *   @author Yearn.finance, tapir
 *   @dev This contract utilizes the 0x DEX aggregator for swapping its reward tokens to target tokens
 *   and eventually the desired tokens at some point. The contract can be inherited by a strategy and
 *   initialized during the strategy's initialization process. Due to the way 0x DEX aggregator and most
 *   DEX aggregators work, the arbitrary swap data must be generated off-chain, and then the swap()
 *   function should be called with the data. This function validates the generated data to ensure no
 *   malicious activity can occur in the low-level call inside the function.
 *
 *   The input token must be fully consumed in the swap, and no partial swaps are allowed. The input
 *   token must be one of the reward tokens, and the output token must be the corresponding target
 *   token for the reward token being swapped. If the data is generated with a minimumAmountOut, the
 *   function in 0x side will check if the final output token amount is greater than the minimumAmountOut; if not,
 *   it will revert.
 *
 *   NOTE: This function performs the swap with its internal balance, meaning that the rewards must be
 *   claimed and idle in the contract. The inherited strategy can claim the rewards in a separate
 *   transaction and then call the swap function. Alternatively, the inherited strategy can create a
 *   function like claimAndSwap() to handle both actions in a single transaction. If there are two
 *   reward tokens, creating a batchSwap that takes two swap data inputs would not be possible due to
 *   EVM call data variable limitations. In this scenario, two separate transactions must be sent for
 *   each swap.
 */

abstract contract ZeroExSwapper {
    using SafeERC20 for ERC20;

    // Each reward token has an associated target token, also known as a sell token.
    // The purpose of having a separate target token for reward tokens, rather than just the asset token,
    // is to optimize liquidity.
    // For example:
    // CRV -> USDC
    // CVX -> sUSD
    // In these cases, the target tokens provide better liquidity options when exchanging the reward tokens.
    // @dev In any point of this contract, rewardToken => address(0) should not be existed.
    // if there is a reward token, then there must be a corresponding target token
    mapping(address => address) public rewardTokenToTargetToken;

    // to keep track of the reward tokens
    address[] public rewardTokens;

    // There will be no setters for this function due to security reasons
    // since strategy will be interacting with this contract by low-level calls
    // Treat it as a constant.
    address public zeroExRouter;

    // Initialize with the strategy
    // NOTE: Should be called only once in the inherited strategys' initialize method!
    function _initializeZeroExSwapper(
        address[] memory initialRewardTokens,
        address[] memory initialTargetTokens,
        address _zeroExRouter
    ) internal {
        require(
            initialRewardTokens.length == initialTargetTokens.length,
            "Length Dismatches"
        );
        require(_zeroExRouter != address(0), "Zero Address");

        // Set the 0x router only once, not settable!
        zeroExRouter = _zeroExRouter;

        // If the strategy inheriting this swapper, there is most likely at least
        // 1 reward token, so no address(0) accepted.
        for (uint i = 0; i < initialRewardTokens.length; ) {
            // cache from mem array to mem var, save gas
            address _rewardToken = initialRewardTokens[i];
            address _targetToken = initialTargetTokens[i];

            require(
                _rewardToken != address(0) && _targetToken != address(0),
                "Zero Address"
            );

            ERC20(_rewardToken).safeApprove(_zeroExRouter, type(uint256).max);
            rewardTokenToTargetToken[_rewardToken] = _targetToken;
            rewardTokens.push(_rewardToken);

            unchecked {
                i = i + 1;
            }
        }
    }

    // @notice Sets the reward token and the corresponding target token (sell target)
    // @dev This function is not for deleting a reward token from the mapping! Only for setting
    // If the given reward token is deprecated, call deleteRewardToken
    // @param rewardToken Reward token that the strategy is entitled
    // @param targetTokenForRewardToken Reward tokens target token for strategy (sell the reward token for this token)
    // NOTE: Restrict this functions caller function, this function should be only callable via a trusted party
    function _setRewardToken(
        address rewardToken,
        address targetTokenForRewardToken
    ) internal {
        require(
            rewardToken != address(0) &&
                targetTokenForRewardToken != address(0),
            "Zero Address"
        );

        ERC20(rewardToken).safeApprove(zeroExRouter, 0);
        ERC20(rewardToken).safeApprove(zeroExRouter, type(uint256).max);

        // if this is already a known reward token and only target token updated via this function
        // then don't change the array, if not push to the array
        if (rewardTokenToTargetToken[rewardToken] == address(0)) {
            rewardTokens.push(rewardToken);
        }
        rewardTokenToTargetToken[rewardToken] = targetTokenForRewardToken;
    }

    // @notice Deletes the reward token from strategies storage
    // @dev Use this when the reward token is no longer entitled for the strategy
    // This function will set both the key and target for the mapping to default values (address(0))
    // @param rewardToken Reward token to delete from the strategy storage
    // NOTE: Restrict this functions caller function, this function should be only callable via a trusted party
    function _deleteRewardToken(address rewardToken) internal {
        require(
            rewardTokenToTargetToken[rewardToken] != address(0),
            "Invalid Reward Token"
        );

        // revoke
        ERC20(rewardToken).safeApprove(zeroExRouter, 0);

        // delete from the mapping
        delete rewardTokenToTargetToken[rewardToken];

        // save gas, copy to memory
        uint256 _length = rewardTokens.length;

        // length can't be 0, it would fail in line 133
        // if there is only 1 reward token, just pop
        if (_length == 1) {
            rewardTokens.pop();
            return;
        }

        for (uint i = 0; i < _length; ) {
            if (rewardTokens[i] == rewardToken) {
                if (i == _length - 1) {
                    rewardTokens.pop(); // we exhausted the loop, pop from the last
                    break;
                }
                rewardTokens[i] = rewardTokens[_length - 1]; // change the last indexs position to "i"
                rewardTokens.pop(); // pop from the last
                break;
            }

            unchecked {
                i = i + 1;
            }
        }
    }

    // @notice This function serves as the primary method for swapping reward tokens to target tokens
    // using the 0x router. The provided swap data is generated off-chain through an API call to the 0x API.
    // This function is responsible for validating the data and executing the swap on-chain.
    //
    // @dev This function performs the swap using its internal balance; therefore, rewards must be claimed
    // before invoking this function. The reward token must be swapped for its target token, or the function
    // will revert.

    // NOTE: This function checks the reward token balance before the low-level call and expects
    // it to be 0, meaning the reward token is fully sold for the target token. It also checks the before and
    // after balances of the target token, expecting the after balance to be greater than the before balance
    // to ensure the destination address of the output token is always address(this).
    //
    // As of the time of writing, 0x contracts have a single destination address for swaps, implying that
    // the entire output token swapped will be sent to address(this). If multiple recipients were allowed,
    // one could return a tiny fraction of the output to this address and send the remainder to a different
    // recipient without reverting the function. To prevent such actions, access control is implemented in
    // the function to only allow trusted entities to call it.
    //
    // Alternatively, multiple functions can be called in 0x for swapping, such as "transformERC20()",
    // "sellTokenForTokenToUniswapV3", "sellToUniswap", "multiplexBatchSellTokenForToken", and many others.
    // As the team continuously adds new solvers, it is not feasible to hardcode all function validations
    // within the swapper (e.g., if (swapData[0] == 0x41) --if transformERC20 called--). The best practice for
    // maintaining this swapper is to manage access controls for trusted entities and ensure that only
    // reward tokens can be swapped for target tokens. Critical working tokens like "asset" should never be
    // included in the rewardTokenToTargetToken mapping for safety reasons.
    //
    // @param swapData Swap data generated off-chain via 0x API
    // NOTE: Restrict this functions caller function, this function should be only callable via a trusted party
    function _swap(
        bytes calldata swapData,
        address rewardToken
    ) internal returns (uint256 boughtTargetToken) {
        require(rewardToken != address(0), "Zero Address");

        // NOTE: Rewards must be idle in the contract
        uint256 rewardTokenBalance = ERC20(rewardToken).balanceOf(
            address(this)
        );

        if (rewardTokenBalance == 0) return 0; // quick exit without revert

        // given token must be a reward token
        address targetToken = rewardTokenToTargetToken[rewardToken];
        require(targetToken != address(0), "Zero Address");

        uint256 targetTokenBalBefore = ERC20(targetToken).balanceOf(
            address(this)
        );

        // Low level call to the zeroExRouter constant address, send the entire gas
        (bool success, ) = zeroExRouter.call(swapData);
        require(success, "SWAP_FAILED");

        uint256 newRewardTokenBalance = ERC20(rewardToken).balanceOf(
            address(this)
        );

        // after the swap reward token balance must decrease since it's swapped to target token
        require(newRewardTokenBalance < rewardTokenBalance, "Swap Failed");

        // If we don't have more target token after swap, this will fail which is expected behaviour
        boughtTargetToken =
            ERC20(targetToken).balanceOf(address(this)) -
            targetTokenBalBefore;

        // If the bought target token is 0 then we failed to swap
        require(boughtTargetToken != 0, "Invalid Target Token");
    }
}
