import pytest
from ape import Contract, project


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
def RELATIVE_APPROX():
    yield 1e-5


########## CONTRACTS TO TEST ############


@pytest.fixture(scope="session")
def uniV3Swapper(daddy, asset):
    uniV3Swapper = daddy.deploy(project.MockUniswapV3Swapper, asset)
    uniV3Swapper = project.IMockUniswapV3Swapper.at(uniV3Swapper.address)

    yield uniV3Swapper


def healthCheck(daddy, asset):
    healthCheck = daddy.deploy(project.MockHealthCheck, asset)
    healthCheck = project.IMockHealthCheck.at(healthCheck.address)

    yield healthCheck


@pytest.fixture(scope="session")
def zero_ex_router():
    zero_ex_router = "0xdef1c0ded9bec7f1a1670819833240f027b25eff"
    yield zero_ex_router


@pytest.fixture(scope="session")
def crv():
    crv = Contract("0xD533a949740bb3306d119CC777fa900bA034cd52")
    yield crv


@pytest.fixture(scope="session")
def cvx():
    cvx = Contract("0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B")
    yield cvx


@pytest.fixture(scope="session")
def cvx_whale(accounts):
    yield accounts["0xF977814e90dA44bFA03b6295A0616a897441aceC"]


@pytest.fixture(scope="session")
def zero_ex_swapper(daddy, tokens, zero_ex_router):
    zero_ex_swapper = daddy.deploy(project.MockStrategy)
    zero_ex_swapper.initializeStrategy(tokens["weth"], zero_ex_router, sender=daddy)
    yield zero_ex_swapper
