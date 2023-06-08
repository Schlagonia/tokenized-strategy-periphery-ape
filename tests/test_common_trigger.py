import ape
from utils.constants import ZERO_ADDRESS


def test__common_trigger_setup(common_trigger, vault, strategy, daddy):
    assert common_trigger.owner() == daddy.address
    assert common_trigger.baseFeeProvider() == ZERO_ADDRESS
    assert common_trigger.acceptableBaseFee() == 0
    assert common_trigger.customStrategyTrigger(strategy.address) == ZERO_ADDRESS
    assert (
        common_trigger.customVaultTrigger(vault.address, strategy.address)
        == ZERO_ADDRESS
    )
