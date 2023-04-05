// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

import {IVault} from "../interfaces/IVault.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface ICustomStrategyTrigger {
    function reportTrigger(address _strategy) external view returns (bool);
}

interface ICustomVaultTrigger {
    function reportTrigger(
        address _vault,
        address _strategy
    ) external view returns (bool);
}

interface IBaseFee {
    function isCurrentBaseFeeAcceptable() external view returns (bool);
}

//TODO: add a forceReportTriggerOnce?
contract CommonReportTrigger is Ownable {
    event UpdatedBaseFeeOracle(address baseFeeOracle);

    event UpdatedCustomStrategyTrigger(
        address indexed strategy,
        address indexed trigger
    );

    event UpdatedCustomVaultTrigger(
        address indexed vault,
        address indexed strategy,
        address indexed trigger
    );

    address public baseFeeOracle;

    mapping(address => address) public customStrategyTrigger;

    mapping(address => mapping(address => address)) public customVaultTrigger;

    function setCustomStrategyTrigger(
        address _strategy,
        address _trigger
    ) external {
        require(msg.sender == IStrategy(_strategy).management(), "!authorized");
        customStrategyTrigger[_strategy] = _trigger;

        emit UpdatedCustomStrategyTrigger(_strategy, _trigger);
    }

    function setCustomVaultTrigger(
        address _vault,
        address _strategy,
        address _trigger
    ) external {
        // TODO: check that the address has the reporting manger role
        require(32 == IVault(_vault).roles(msg.sender), "!authorized");
        customVaultTrigger[_vault][_strategy] = _trigger;

        emit UpdatedCustomVaultTrigger(_vault, _strategy, _trigger);
    }

    function reportTrigger(address _strategy) external view returns (bool) {
        address _trigger = customStrategyTrigger[_strategy];

        if (_trigger != address(0)) {
            return ICustomStrategyTrigger(_trigger).reportTrigger(_strategy);
        }

        address _baseFeeOracle = baseFeeOracle;
        if (_baseFeeOracle != address(0)) {
            if (!IBaseFee(_baseFeeOracle).isCurrentBaseFeeAcceptable())
                return false;
        }

        return
            block.timestamp - IStrategy(_strategy).lastReport() >
            IStrategy(_strategy).profitMaxUnlockTime();
    }

    function vaultReportTrigger(
        address _vault,
        address _strategy
    ) external view returns (bool) {
        address _trigger = customVaultTrigger[_vault][_strategy];

        if (_trigger != address(0)) {
            return
                ICustomVaultTrigger(_trigger).reportTrigger(_vault, _strategy);
        }

        address _baseFeeOracle = baseFeeOracle;
        if (_baseFeeOracle != address(0)) {
            if (!IBaseFee(_baseFeeOracle).isCurrentBaseFeeAcceptable())
                return false;
        }

        IVault.StrategyParams memory params = IVault(_vault).strategies(
            _strategy
        );

        if (params.activation == 0 || params.currentDebt == 0) return false;

        return
            block.timestamp - params.lastReport >
            IVault(_vault).profitMaxUnlockTime();
    }

    /**
     * @notice
     *  Used to set our baseFeeOracle, which checks the network's current base
     *  fee price to determine whether it is an optimal time to harvest or tend.
     *
     *  This may only be called by governance or management.
     * @param _baseFeeOracle Address of our baseFeeOracle
     */
    function setBaseFeeOracle(address _baseFeeOracle) external onlyOwner {
        baseFeeOracle = _baseFeeOracle;

        emit UpdatedBaseFeeOracle(_baseFeeOracle);
    }
}
