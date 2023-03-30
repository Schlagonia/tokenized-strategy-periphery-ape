import pytest


def test_swap_to_weth(uniV3Swapper, weth, asset, amount, whale, daddy):
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


def test_swap_from_weth(uniV3Swapper, weth, asset, weth_amount, whale, daddy):
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


## TODO: multi hop swaps. Change the router, base and minamount and revert when a fee is not set
