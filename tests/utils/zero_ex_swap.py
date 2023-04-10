import decimal
import requests


def convert_to_string(number):
    number = decimal.Decimal(
        number
    )  # Creating Decimal Instance from Number(12.1231e-09)
    digit = abs(
        number.as_tuple().exponent
    )  # Getting the precision count // If 0.123123 -> output will be 6
    number_str = f"{float(number):.{digit}f}"  # returning with specific precision
    number_str = number_str.replace(".", "")
    return number_str


def getDefaultQuote(buy, sell, amount):
    amount = convert_to_string(amount)
    params = {
        "buyToken": buy,  # symbol or address
        "sellToken": sell,  # symbol or address
        "sellAmount": str(amount),
    }

    # endpoints for other chains: https://docs.0x.org/introduction/0x-cheat-sheet
    URL = "https://api.0x.org/swap/v1/quote?"  # for mainnet quotes

    response = None
    try:
        response = requests.get(URL, params=params)
    except Exception as e:
        raise e

    return response.json()["data"]
