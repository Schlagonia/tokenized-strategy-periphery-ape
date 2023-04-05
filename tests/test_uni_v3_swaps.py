import pytest
import ape
from ape import Contract


def test__swap_from__asset_to_weth(uniV3Swapper, weth, asset, amount, whale, daddy):
    # set weth asset fees
    uniV3Swapper.setUniFees(weth, asset, 500, sender=daddy)
    # send some asset to the contract
    asset.transfer(uniV3Swapper.address, amount, sender=whale)

    assert asset.balanceOf(uniV3Swapper.address) == amount
    assert weth.balanceOf(uniV3Swapper.address) == 0

    tx = uniV3Swapper.swapFrom(asset.address, weth.address, amount, 0, sender=daddy)

    assert asset.balanceOf(uniV3Swapper.address) == 0
    assert weth.balanceOf(uniV3Swapper.address) > 0
    assert weth.balanceOf(uniV3Swapper.address) == tx.return_value


def test__swap_from__weth_to_asset(uniV3Swapper, weth, asset, weth_amount, whale, daddy):
    # set weth asset fees
    uniV3Swapper.setUniFees(weth, asset, 500, sender=daddy)

    # send some weth to the contract
    weth.transfer(uniV3Swapper.address, weth_amount, sender=whale)

    assert weth.balanceOf(uniV3Swapper.address) == weth_amount
    assert asset.balanceOf(uniV3Swapper.address) == 0

    tx = uniV3Swapper.swapFrom(
        weth.address, asset.address, weth_amount, 0, sender=daddy
    )

    assert weth.balanceOf(uniV3Swapper.address) == 0
    assert asset.balanceOf(uniV3Swapper.address) > 0
    assert asset.balanceOf(uniV3Swapper.address) == tx.return_value


def test__swap_to__weth_from_asset(uniV3Swapper, weth, asset, amount, whale, daddy):
    # set weth asset fees
    uniV3Swapper.setUniFees(weth, asset, 500, sender=daddy)
    # send some asset to the contract
    asset.transfer(uniV3Swapper.address, amount, sender=whale)

    assert asset.balanceOf(uniV3Swapper.address) == amount
    assert weth.balanceOf(uniV3Swapper.address) == 0

    to_get = int(1e16)

    tx = uniV3Swapper.swapTo(asset.address, weth.address, to_get, amount, sender=daddy)

    assert asset.balanceOf(uniV3Swapper.address) < amount
    assert weth.balanceOf(uniV3Swapper.address) == to_get
    assert amount - asset.balanceOf(uniV3Swapper.address) == tx.return_value


def test__swap_to__asset_from_weth(uniV3Swapper, weth, asset, weth_amount, whale, daddy):
    # set weth asset fees
    uniV3Swapper.setUniFees(weth, asset, 500, sender=daddy)

    # send some weth to the contract
    weth.transfer(uniV3Swapper.address, weth_amount, sender=whale)

    assert weth.balanceOf(uniV3Swapper.address) == weth_amount
    assert asset.balanceOf(uniV3Swapper.address) == 0

    to_get = int(100e6)

    tx = uniV3Swapper.swapTo(
        weth.address, asset.address, to_get, weth_amount, sender=daddy
    )

    assert weth.balanceOf(uniV3Swapper.address) < weth_amount
    assert asset.balanceOf(uniV3Swapper.address) == to_get
    assert weth_amount - weth.balanceOf(uniV3Swapper.address) == tx.return_value


def test__swap_from__multi_hop(uniV3Swapper, weth, asset, amount, whale, daddy, tokens):
    swap_to = Contract(tokens["dai"])
    # set fees
    uniV3Swapper.setUniFees(weth, asset, 500, sender=daddy)
    uniV3Swapper.setUniFees(weth, swap_to, 500, sender=daddy)
    
    # send some asset to the contract
    asset.transfer(uniV3Swapper.address, amount, sender=whale)

    assert asset.balanceOf(uniV3Swapper.address) == amount
    assert weth.balanceOf(uniV3Swapper.address) == 0
    assert swap_to.balanceOf(uniV3Swapper.address) == 0

    tx = uniV3Swapper.swapFrom(asset.address, swap_to.address, amount, 0, sender=daddy)

    assert asset.balanceOf(uniV3Swapper.address) == 0
    assert weth.balanceOf(uniV3Swapper.address) == 0
    assert swap_to.balanceOf(uniV3Swapper.address) > 0
    # assert swap_to.balanceOf(uniV3Swapper.address) == tx.return_value
    


def test__swap_to__multi_hop(uniV3Swapper, weth, asset, amount, whale, daddy, tokens):
    swap_to = Contract(tokens["dai"])
    # set weth asset fees
    uniV3Swapper.setUniFees(weth, asset, 500, sender=daddy)
    uniV3Swapper.setUniFees(weth, swap_to, 500, sender=daddy)

    # send some asset to the contract
    asset.transfer(uniV3Swapper.address, amount, sender=whale)

    assert asset.balanceOf(uniV3Swapper.address) == amount
    assert weth.balanceOf(uniV3Swapper.address) == 0
    assert swap_to.balanceOf(uniV3Swapper.address) == 0

    to_get = int(1e16)

    tx = uniV3Swapper.swapTo(asset.address, swap_to.address, to_get, amount, sender=daddy)

    assert asset.balanceOf(uniV3Swapper.address) < amount
    assert swap_to.balanceOf(uniV3Swapper.address) == to_get
    assert weth.balanceOf(uniV3Swapper.address) == 0
    # assert amount - asset.balanceOf(uniV3Swapper.address) == tx.return_value


def test__swap_from__min_out__reverts(uniV3Swapper, weth, asset, amount, whale, daddy):
    # set weth asset fees
    uniV3Swapper.setUniFees(weth, asset, 500, sender=daddy)
    # send some asset to the contract
    asset.transfer(uniV3Swapper.address, amount, sender=whale)

    assert asset.balanceOf(uniV3Swapper.address) == amount
    assert weth.balanceOf(uniV3Swapper.address) == 0

    min_out = int(1e30)

    with ape.reverts():
        tx = uniV3Swapper.swapFrom(asset.address, weth.address, amount, min_out, sender=daddy)

    assert asset.balanceOf(uniV3Swapper.address) == amount
    assert weth.balanceOf(uniV3Swapper.address) == 0


def test__swap_to__max_in__reverts(uniV3Swapper, weth, asset, amount, whale, daddy):
    # set weth asset fees
    uniV3Swapper.setUniFees(weth, asset, 500, sender=daddy)
    # send some asset to the contract
    asset.transfer(uniV3Swapper.address, amount, sender=whale)

    assert asset.balanceOf(uniV3Swapper.address) == amount
    assert weth.balanceOf(uniV3Swapper.address) == 0

    to_get = int(1e16)
    max_from = int(1)

    with ape.reverts():
        uniV3Swapper.swapTo(asset.address, weth.address, to_get, max_from, sender=daddy)

    assert asset.balanceOf(uniV3Swapper.address) == amount
    assert weth.balanceOf(uniV3Swapper.address) == 0


def test__bad_router__reverts(uniV3Swapper, weth, asset, amount, whale, daddy):
    uniV3Swapper.setUniFees(weth, asset, 500, sender=daddy)
    
    uniV3Swapper.setRouter(daddy, sender=daddy)

    assert uniV3Swapper.router() == daddy

    # send some asset to the contract
    asset.transfer(uniV3Swapper.address, amount, sender=whale)

    assert asset.balanceOf(uniV3Swapper.address) == amount
    assert weth.balanceOf(uniV3Swapper.address) == 0


    with ape.reverts():
        uniV3Swapper.swapFrom(asset.address, weth.address, amount, 0, sender=daddy)

    assert asset.balanceOf(uniV3Swapper.address) == amount
    assert weth.balanceOf(uniV3Swapper.address) == 0


def test__bad_base__reverts(uniV3Swapper, weth, asset, amount, whale, daddy):
    uniV3Swapper.setUniFees(weth, asset, 500, sender=daddy)
    
    uniV3Swapper.setBase(daddy, sender=daddy)

    assert uniV3Swapper.base() == daddy

    # send some asset to the contract
    asset.transfer(uniV3Swapper.address, amount, sender=whale)

    assert asset.balanceOf(uniV3Swapper.address) == amount
    assert weth.balanceOf(uniV3Swapper.address) == 0


    with ape.reverts():
        uniV3Swapper.swapFrom(asset.address, weth.address, amount, 0, sender=daddy)

    assert asset.balanceOf(uniV3Swapper.address) == amount
    assert weth.balanceOf(uniV3Swapper.address) == 0

