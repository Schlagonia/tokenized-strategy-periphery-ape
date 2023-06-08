import pytest
from ape import Contract, project
from utils.constants import MAX_INT, WEEK, ROLES


@pytest.fixture(scope="session")
def daddy(accounts):
    yield accounts["0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52"]


@pytest.fixture(scope="session")
def user(accounts):
    yield accounts[0]


@pytest.fixture(scope="session")
def rewards(accounts):
    yield accounts[1]


@pytest.fixture(scope="session")
def management(accounts):
    yield accounts[2]


@pytest.fixture(scope="session")
def keeper(accounts):
    yield accounts[3]


@pytest.fixture(scope="session")
def tokens():
    tokens = {
        "weth": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        "dai": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
        "usdc": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    }
    yield tokens


@pytest.fixture(scope="session")
def asset(tokens):
    yield Contract(tokens["usdc"])


@pytest.fixture(scope="session")
def whale(accounts):
    # In order to get some funds for the token you are about to use,
    # The Balancer vault stays steady ballin on almost all tokens
    # NOTE: If `asset` is a balancer pool this may cause issues on amount checks.
    yield accounts["0xBA12222222228d8Ba445958a75a0704d566BF2C8"]


@pytest.fixture(scope="session")
def amount(asset, user, whale):
    amount = 100 * 10 ** asset.decimals()
    asset.transfer(user, amount, sender=whale)
    yield amount


@pytest.fixture(scope="session")
def weth(tokens):
    yield Contract(tokens["weth"])


@pytest.fixture(scope="session")
def weth_amount(user, weth):
    weth_amount = 10 ** weth.decimals()
    user.transfer(weth, weth_amount)
    yield weth_amount


@pytest.fixture(scope="session")
def create_vault(project, daddy):
    def create_vault(
        asset,
        governance=daddy,
        deposit_limit=MAX_INT,
        max_profit_locking_time=WEEK,
        vault_name="Test Vault",
        vault_symbol="V3",
    ):

        vault = daddy.deploy(
            project.dependencies["yearn-vaults"]["master"].VaultV3,
            asset,
            vault_name,
            vault_symbol,
            governance,
            max_profit_locking_time,
        )

        vault.set_role(
            daddy.address,
            ROLES.ADD_STRATEGY_MANAGER
            | ROLES.REVOKE_STRATEGY_MANAGER
            | ROLES.FORCE_REVOKE_MANAGER
            | ROLES.ACCOUNTANT_MANAGER
            | ROLES.QUEUE_MANAGER
            | ROLES.REPORTING_MANAGER
            | ROLES.DEBT_MANAGER
            | ROLES.MAX_DEBT_MANAGER
            | ROLES.DEPOSIT_LIMIT_MANAGER
            | ROLES.MINIMUM_IDLE_MANAGER
            | ROLES.PROFIT_UNLOCK_MANAGER
            | ROLES.SWEEPER
            | ROLES.EMERGENCY_MANAGER,
            sender=daddy,
        )

        # set vault deposit
        vault.set_deposit_limit(deposit_limit, sender=daddy)

        return vault

    yield create_vault


@pytest.fixture(scope="function")
def vault(asset, create_vault):
    vault = create_vault(asset)
    yield vault


@pytest.fixture
def create_strategy(project, management, asset):
    def create_strategy(token=asset):
        strategy = management.deploy(project.MockStrategy, token.address)

        return strategy

    yield create_strategy


@pytest.fixture(scope="function")
def strategy(asset, create_strategy):
    strategy = create_strategy(asset)
    yield strategy


@pytest.fixture(scope="function")
def create_vault_and_strategy(strategy, vault, deposit_into_vault):
    def create_vault_and_strategy(account, amount_into_vault):
        deposit_into_vault(vault, amount_into_vault)
        vault.add_strategy(strategy.address, sender=account)
        return vault, strategy

    yield create_vault_and_strategy


@pytest.fixture(scope="session")
def RELATIVE_APPROX():
    yield 1e-5


########## CONTRACTS TO TEST ############


@pytest.fixture(scope="session")
def uniV3Swapper(daddy, asset):
    uniV3Swapper = daddy.deploy(project.MockUniswapV3Swapper, asset)
    uniV3Swapper = project.IMockUniswapV3Swapper.at(uniV3Swapper.address)

    yield uniV3Swapper


@pytest.fixture(scope="session")
def healthCheck(daddy, asset):
    healthCheck = daddy.deploy(project.MockHealthCheck, asset)
    healthCheck = project.IMockHealthCheck.at(healthCheck.address)

    yield healthCheck


@pytest.fixture(scope="session")
def common_trigger(daddy):
    common_trigger = daddy.deploy(project.CommonReportTrigger)

    yield common_trigger
