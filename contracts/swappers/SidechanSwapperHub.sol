// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IDexHandler {
    function executeSwap(uint256 amount, address tokenIn, address tokenOut, address router, uint16 param) external;
}

/**
 * @title SidechainSwapperHub
 * @author Yearn.finance
 * @dev This is a periphery contract intended to be used by Yearn V3 tokenized vaults.
 * It contains a set of [tokenIn, tokenOut] and associated swap routes, generated off-chain
 * and managed by owner (multi sig). It will allow for complex swaps back to the vault's
 * original asset (e.g. an LP position).
 */

contract SidechainSwapperHub is Ownable {
    event PathStored(address indexed tokenIn, address indexed tokenOut);
    event DexHandlerSet(uint16 indexed dexIdentifier, address indexed handler);
    event PathDeleted(address indexed tokenIn, address indexed tokenOut);
    event DexHandlerDeleted(uint16 indexed dexIdentifier);

    /**
     * @dev StorePath contains the route struct for unique [tokenIn, tokenOut] combinaisons.
     * RouteStep contains each hop, with a unique dexIdentifier and param for protocol-specific
     * argument (e.g. UniV3 fee, Curve swap or add liqudity, etc.).
     */

    struct StoredPath {
        address tokenIn;
        address tokenOut;
        RouteStep[] route;
    }

    struct RouteStep {
        uint16 dexIdentifier;
        address tokenIn;
        address tokenOut;
        address router;
        uint16 param;
    }

    mapping(bytes32 => StoredPath) internal storedPaths;
    mapping(uint16 => address) public dexHandlers; // Mapping for DEX handler contracts

    function storePath(address _tokenIn, address _tokenOut, RouteStep[] memory _route) external onlyOwner {
        bytes32 key = keccak256(abi.encodePacked(_tokenIn, _tokenOut));

        // Create a new StoredPath
        StoredPath memory newPath = StoredPath({tokenIn: _tokenIn, tokenOut: _tokenOut, route: _route});

        // Check allowance for each step of the route
        for (uint256 i = 0; i < _route.length; i++) {
            _checkAllowance(_route[i].router, ERC20(_route[i].tokenIn), type(uint256).max);
        }

        // Store the new path, overwriting if it already exists
        storedPaths[key] = newPath;

        emit PathStored(_tokenIn, _tokenOut);
    }

    function setDexHandler(uint16 dexIdentifier, address handler) external onlyOwner {
        // Store the dexIdentifier, overwriting if it already exists
        dexHandlers[dexIdentifier] = handler;

        emit DexHandlerSet(dexIdentifier, handler);
    }

    function deleteStoredPath(address _tokenIn, address _tokenOut) external onlyOwner {
        bytes32 key = keccak256(abi.encodePacked(_tokenIn, _tokenOut));

        // Check if path exists
        require(storedPaths[key].tokenIn != address(0), "Path does not exist");

        // Delete the path
        delete storedPaths[key];

        emit PathDeleted(_tokenIn, _tokenOut);
    }

    function deleteDexHandler(uint16 dexIdentifier) external onlyOwner {
        // Check if dexIdentifier exists
        require(dexHandlers[dexIdentifier] != address(0), "DEX Handler does not exist");

        // Delete the DEX Handler
        delete dexHandlers[dexIdentifier];

        emit DexHandlerDeleted(dexIdentifier);
    }

    function getStoredPath(address _tokenIn, address _tokenOut) public view returns (StoredPath memory) {
        bytes32 key = keccak256(abi.encodePacked(_tokenIn, _tokenOut));
        return storedPaths[key];
    }

    /**
     * @notice  This function serves as the primary method for swapping reward tokens to target
     * tokens using the stored routes.
     */

    function _swapForStrategy(address tokenIn, address tokenOut, uint256 amount, uint256 minAmountOut)
        external
        returns (uint256 amountOut)
    {
        if (amount == 0) return 0; // quick exit without revert
        ERC20(tokenIn).transferFrom(msg.sender, address(this), amount);
        bytes32 key = keccak256(abi.encodePacked(tokenIn, tokenOut));
        StoredPath memory path = storedPaths[key];
        require(path.tokenIn != address(0), "No path for given token pair");

        if (path.tokenIn != address(0)) {
            // Found a matching path, process the route
            for (uint256 i = 0; i < path.route.length; i++) {
                RouteStep memory step = path.route[i];

                if (i != 0) {
                    // if this is not the first hop, amount should be the balance
                    amount = ERC20(step.tokenIn).balanceOf(address(this));
                }

                // Call the handler contract for the given DEX
                address handlerAddress = dexHandlers[step.dexIdentifier];
                require(handlerAddress != address(0), "DEX identifier not found");

                // Delegatecall to the handler contract
                (bool success,) = handlerAddress.delegatecall(
                    abi.encodeWithSignature(
                        "executeSwap(uint256,address,address,address,uint16)",
                        amount,
                        step.tokenIn,
                        step.tokenOut,
                        step.router,
                        step.param
                    )
                );

                require(success, "executeSwap failed");
            }
        }
        amountOut = ERC20(tokenOut).balanceOf(address(this));
        require(amountOut >= minAmountOut, "Insufficient output amount");
        ERC20(tokenOut).transfer(msg.sender, amountOut);
        return amountOut;
    }

    function _checkAllowance(address _contract, address _token, uint256 _amount) internal {
        if (ERC20(_token).allowance(address(this), _contract) < _amount) {
            ERC20(_token).approve(_contract, 0);
            ERC20(_token).approve(_contract, _amount);
        }
    }
}
