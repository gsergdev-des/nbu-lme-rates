@echo off
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText('%~f0');Invoke-Expression $s.Substring($s.IndexOf('#'+'PSCODE'))"
echo.
timeout /t 20 2>nul || ping -n 11 127.0.0.1 >nul
exit /b

#PSCODE
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$LmeUrl     = 'https://www.westmetall.com/en/markdaten.php'
$NbuUrl     = 'https://bank.gov.ua/NBUStatService/v1/statdirectory/exchange?json'
$Currencies = @('USD', 'EUR', 'XAU', 'XAG')
$Inv        = [Globalization.CultureInfo]::InvariantCulture

function Get-LmePrices {
    $html = (Invoke-WebRequest -Uri $LmeUrl -UserAgent 'Mozilla/5.0' -UseBasicParsing -TimeoutSec 10).Content

    $dateMatch = [regex]::Match($html, 'Official LME-Prices.*?<th class="number">([^<]+)</th>', 'Singleline')
    $date = if ($dateMatch.Success) { $dateMatch.Groups[1].Value.Trim() } else { 'неизвестно' }

    $tableMatch = [regex]::Match($html, 'Official LME-Prices.*?<tbody>(.*?)</table>', 'Singleline')
    $tableHtml = if ($tableMatch.Success) { $tableMatch.Groups[1].Value } else { '' }

    $pattern = 'field=LME_\w+_cash" class="block">\s*([^<]+?)\s*</a>.*?' +
               'field=LME_\w+_cash" class="block">\s*([\d,.]+)\s*</a>.*?' +
               'field=LME_\w+_cash" class="block">\s*([\d,.]+)\s*</a>'

    $rows = foreach ($m in [regex]::Matches($tableHtml, $pattern, 'Singleline')) {
        [pscustomobject]@{
            Name   = $m.Groups[1].Value.Trim()
            Cash   = $m.Groups[2].Value.Trim()
            Month3 = $m.Groups[3].Value.Trim()
        }
    }

    [pscustomobject]@{ Date = $date; Rows = @($rows) }
}

function Get-NbuRates {
    $data = Invoke-RestMethod -Uri $NbuUrl -TimeoutSec 10
    $result = @{}
    foreach ($item in $data) {
        if ($Currencies -contains $item.cc) { $result[$item.cc] = $item }
    }
    $result
}

function Show-LmePrices {
    $lme = Get-LmePrices
    Write-Host "Официальные цены LME (US`$/тонна) на $($lme.Date):" -ForegroundColor Cyan
    foreach ($r in $lme.Rows) {
        Write-Host ('  {0,-10} ' -f $r.Name) -ForegroundColor Yellow -NoNewline
        Write-Host 'наличный: ' -NoNewline
        Write-Host ('{0,10}' -f $r.Cash) -ForegroundColor Green -NoNewline
        Write-Host '   3 мес.: ' -NoNewline
        Write-Host ('{0,10}' -f $r.Month3) -ForegroundColor Green
    }
}

function Show-NbuRates {
    $rates = Get-NbuRates
    Write-Host 'Курсы валют НБУ:' -ForegroundColor Cyan
    foreach ($code in $Currencies) {
        if ($rates.ContainsKey($code)) {
            $item = $rates[$code]
            $rate = ([double]$item.rate).ToString('F4', $Inv)
            Write-Host ('  {0}: ' -f $code) -ForegroundColor Yellow -NoNewline
            Write-Host ('{0} грн' -f $rate) -ForegroundColor Green -NoNewline
            Write-Host ('  (на {0})' -f $item.exchangedate) -ForegroundColor DarkGray
        }
        else {
            Write-Host ('  {0}: нет данных' -f $code) -ForegroundColor Red
        }
    }
}

try   { Show-LmePrices }
catch { Write-Host "Ошибка при получении цен LME: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host ''

try   { Show-NbuRates }
catch { Write-Host "Ошибка при получении курсов НБУ: $($_.Exception.Message)" -ForegroundColor Red }
