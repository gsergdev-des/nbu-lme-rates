import json
import sys
import urllib.request

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

NBU_URL = "https://bank.gov.ua/NBUStatService/v1/statdirectory/exchange?json"
CURRENCIES = ("USD", "EUR", "XAU", "XAG")


def get_rates():
    with urllib.request.urlopen(NBU_URL, timeout=10) as response:
        data = json.loads(response.read().decode("utf-8"))
    return {item["cc"]: item for item in data if item["cc"] in CURRENCIES}


def main():
    rates = get_rates()
    print("Курсы валют НБУ:")
    for code in CURRENCIES:
        item = rates.get(code)
        if item:
            print(f"  {code}: {item['rate']:.4f} грн  (на {item['exchangedate']})")
        else:
            print(f"  {code}: нет данных")


if __name__ == "__main__":
    main()
