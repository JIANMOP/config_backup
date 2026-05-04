@echo off
:: Set UTF-8 encoding to avoid garbled output
chcp 65001 >nul 2>&1

:: Configure your proxy address here (MODIFY THIS!)
set "PROXY_SERVER=http://127.0.0.1:10808"

:: Main logic - check input parameters
if "%~1"=="" (
    echo ==============================
    echo Proxy Control Script Usage
    echo ==============================
    echo Commands:
    echo   proxy on      - Enable HTTP/HTTPS proxy
    echo   proxy off     - Disable HTTP/HTTPS proxy
    echo   proxy status  - Check current proxy status
    echo Example:
    echo   proxy on
    echo   proxy status
    goto :EOF
)

:: Enable proxy
if "%~1"=="on" (
    set "http_proxy=%PROXY_SERVER%"
    set "https_proxy=%PROXY_SERVER%"
    echo [SUCCESS] Proxy enabled successfully!
    goto :EOF
)

:: Disable proxy
if "%~1"=="off" (
    set "http_proxy="
    set "https_proxy="
    echo [SUCCESS] Proxy disabled successfully!
    echo   All proxy environment variables cleared.
    goto :EOF
)

:: Check proxy status
if "%~1"=="status" (
    echo ==============================
    echo Current Proxy Status
    echo ==============================
    if defined http_proxy (
        echo   HTTP Proxy:  %http_proxy%
    ) else (
        echo   HTTP Proxy:  Not set
    )
    if defined https_proxy (
        echo   HTTPS Proxy: %https_proxy%
    ) else (
        echo   HTTPS Proxy: Not set
    )
	echo.
	curl -s ipinfo.io
	echo.
    echo ==============================
    goto :EOF
)

:: Invalid parameter handling
echo [ERROR] Invalid command: %1
echo Use one of: on / off / status
goto :EOF