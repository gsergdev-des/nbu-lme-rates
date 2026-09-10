import re
import sys
import urllib.request

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

URL = "https://www.westmetall.com/en/markdaten.php"
HEADERS = {"User-Agent": "Mozilla/5.0"}


def get_lme_prices():
    req = urllib.request.Request(URL, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=10) as response:
        html = response.read().decode("utf-8", errors="ignore")

    date_match = re.search(
        r'Official LME-Prices.*?<th class="number">([^<]+)</th>', html, re.S
    )
    date = date_match.group(1).strip() if date_match else "неизвестно"

    table_match = re.search(
        r'Official LME-Prices.*?<tbody>(.*?)</table>', html, re.S
    )
    table_html = table_match.group(1) if table_match else ""

    rows = re.findall(
        r'field=LME_\w+_cash" class="block">\s*([^<]+?)\s*</a>.*?'
        r'field=LME_\w+_cash" class="block">\s*([\d,.]+)\s*</a>.*?'
        r'field=LME_\w+_cash" class="block">\s*([\d,.]+)\s*</a>',
        table_html,
        re.S,
    )

    return date, [(name.strip(), cash.strip(), month3.strip()) for name, cash, month3 in rows]


def main():
    date, rows = get_lme_prices()
    print(f"Официальные цены LME (US$/тонна) на {date}:")
    for name, cash, month3 in rows:
        print(f"  {name:<10} наличный: {cash:>10}   3 мес.: {month3:>10}")


if __name__ == "__main__":
    main()
