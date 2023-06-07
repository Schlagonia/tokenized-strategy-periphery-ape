import pytest
import ape
from ape import reverts
from utils.helpers import (
    check_normal_flow,
    deposit,
    redeem_and_check,
    increase_time,
    days_to_secs,
)


def test__health_check_setup(chain, healthCheck, asset, amount, user):
    # Defaults to false
    assert healthCheck.doHealthCheck() == False

    # Defaults to 100%
    assert healthCheck.profitLimitRatio() == 10_000

    # Defaults to 0%
    assert healthCheck.lossLimitRatio() == 0

    check_normal_flow(chain, healthCheck, asset, amount, user)

    # Should stil be to false
    assert healthCheck.doHealthCheck() == False

    # Should stil be to 100%
    assert healthCheck.profitLimitRatio() == 10_000

    # Should stil be to 0%
    assert healthCheck.lossLimitRatio() == 0


def test__limit_limits(healthCheck, asset, amount, daddy):
    # Defaults to false
    assert healthCheck.doHealthCheck() == False

    # Defaults to 100%
    assert healthCheck.profitLimitRatio() == 10_000

    # Defaults to 0%
    assert healthCheck.lossLimitRatio() == 0

    with reverts("!zero profit"):
        healthCheck.setProfitLimitRatio(0, sender=daddy)

    # Should stil be to false
    assert healthCheck.doHealthCheck() == False

    # Should stil be to 100%
    assert healthCheck.profitLimitRatio() == 10_000

    # Should stil be to 0%
    assert healthCheck.lossLimitRatio() == 0

    max = 10_000

    with reverts("!loss limit"):
        healthCheck.setLossLimitRatio(max, sender=daddy)

    # Should stil be to false
    assert healthCheck.doHealthCheck() == False

    # Should stil be to 100%
    assert healthCheck.profitLimitRatio() == 10_000

    # Should stil be to 0%
    assert healthCheck.lossLimitRatio() == 0


def test__normal_health_check(chain, healthCheck, asset, amount, user, daddy, whale):
    # Set do Health check to true
    healthCheck.setDoHealthCheck(True, sender=daddy)

    # deposit
    deposit(healthCheck, asset, amount, user)

    profit = amount // 10

    # simulate earning a profit
    asset.transfer(healthCheck.address, profit, sender=whale)

    assert healthCheck.doHealthCheck() == True

    tx = healthCheck.report(sender=daddy)

    real_profit, loss = tx.return_value

    # Make sure we reported the correct profit
    assert profit == real_profit

    # Healtch Check should still be on
    assert healthCheck.doHealthCheck() == True

    increase_time(chain, healthCheck.profitMaxUnlockTime())

    redeem_and_check(healthCheck, asset, amount, user)


def test__to_much_profit__reverts__increase_limit(
    chain, healthCheck, asset, amount, user, daddy, whale
):
    # Set do Health check to true
    healthCheck.setDoHealthCheck(True, sender=daddy)

    # deposit
    deposit(healthCheck, asset, amount, user)

    # Defaults to 100% so should revert if over amount
    profit = amount + 1

    # simulate earning the profit
    asset.transfer(healthCheck.address, profit, sender=whale)

    assert healthCheck.doHealthCheck() == True

    with reverts("!healthcheck"):
        healthCheck.report(sender=daddy)

    assert healthCheck.doHealthCheck() == True

    # Increase the limit enough to allow profit
    healthCheck.setProfitLimitRatio(10_001, sender=daddy)

    tx = healthCheck.report(sender=daddy)

    real_profit, loss = tx.return_value

    assert profit == real_profit

    assert healthCheck.doHealthCheck() == True


def test__loss__reverts__increase_limit(
    chain, healthCheck, asset, amount, user, daddy, whale
):
    # Set do Health check to true
    healthCheck.setDoHealthCheck(True, sender=daddy)

    # deposit
    deposit(healthCheck, asset, amount, user)

    # Loose .01%
    loss = amount // 10_000

    # simulate earning the profit
    asset.transfer(daddy.address, loss, sender=healthCheck)

    assert healthCheck.doHealthCheck() == True

    with reverts("!healthcheck"):
        healthCheck.report(sender=daddy)

    assert healthCheck.doHealthCheck() == True

    # Increase the limit enough to allow 1% loss
    healthCheck.setLossLimitRatio(1, sender=daddy)

    tx = healthCheck.report(sender=daddy)

    profit, real_loss = tx.return_value

    assert loss == real_loss

    assert healthCheck.doHealthCheck() == True


def test__to_much_profit__reverts__turn_off_check(
    chain, healthCheck, asset, amount, user, daddy, whale
):
    # Set do Health check to true
    healthCheck.setDoHealthCheck(True, sender=daddy)

    # deposit
    deposit(healthCheck, asset, amount, user)

    # Defaults to 100% so should revert if over amount
    profit = amount + 1

    # simulate earning the profit
    asset.transfer(healthCheck.address, profit, sender=whale)

    assert healthCheck.doHealthCheck() == True

    with reverts("!healthcheck"):
        healthCheck.report(sender=daddy)

    assert healthCheck.doHealthCheck() == True

    # Turn off the health check
    healthCheck.setDoHealthCheck(False, sender=daddy)

    tx = healthCheck.report(sender=daddy)

    real_profit, loss = tx.return_value

    assert profit == real_profit

    assert healthCheck.doHealthCheck() == False


def test__loss__reverts__turn_off_check(
    chain, healthCheck, asset, amount, user, daddy, whale
):
    # Set do Health check to true
    healthCheck.setDoHealthCheck(True, sender=daddy)

    # deposit
    deposit(healthCheck, asset, amount, user)

    # Loose .01%
    loss = amount // 10_000

    # simulate earning the profit
    asset.transfer(daddy.address, loss, sender=healthCheck)

    assert healthCheck.doHealthCheck() == True

    with reverts("!healthcheck"):
        healthCheck.report(sender=daddy)

    assert healthCheck.doHealthCheck() == True

    # Turn off the health check
    healthCheck.setDoHealthCheck(False, sender=daddy)

    tx = healthCheck.report(sender=daddy)

    profit, real_loss = tx.return_value

    assert loss == real_loss

    assert healthCheck.doHealthCheck() == False
