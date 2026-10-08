@echo off
title WiFi IP Switch Tool
color 0A

:: WiFi IP Switch Tool
:: Function: One-click switch between DHCP and a preset static IP
:: Note: Must be run as Administrator

:: Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator.
    echo Please right-click the script and select "Run as administrator".
    pause
    exit /b 1
)

:: Define the network connection name (edit if needed)
set "ConnectionName=WLAN"

:: Define preset static IP settings (edit if needed)
set "STATIC_IP=172.22.102.59"
set "STATIC_MASK=255.255.255.0"
set "STATIC_GATEWAY=172.22.102.254"
set "DNS1=172.22.22.1"
set "DNS2=172.22.22.2"

:: Check that the network connection exists
netsh interface show interface | find "%ConnectionName%" >nul
if %errorlevel% neq 0 (
    echo ERROR: Network connection "%ConnectionName%" was not found.
    echo Please edit the ConnectionName variable in this script to match your adapter.
    echo.
    echo All network connections on this system:
    echo.
    netsh interface show interface
    echo.
    pause
    exit /b 1
)

:MENU
cls
echo ==================================================
echo           WiFi IP Switch Tool
echo ==================================================
echo.
echo  Current connection: %ConnectionName%
echo.
echo  1. Switch to STATIC IP  (%STATIC_IP%)
echo  2. Switch to DHCP (auto)
echo  3. Show current IP configuration
echo  4. Flush DNS cache
echo  5. Exit
echo.
echo ==================================================
echo.

choice /C 12345 /N /M "Select an option [1-5]: "

if errorlevel 5 goto EXIT
if errorlevel 4 goto FLUSH_DNS
if errorlevel 3 goto SHOW_IP
if errorlevel 2 goto SET_DHCP
if errorlevel 1 goto SET_STATIC_IP

:SET_STATIC_IP
cls
echo ==================================================
echo           Switch to Static IP
echo ==================================================
echo.
echo   IP Address:      %STATIC_IP%
echo   Subnet Mask:     %STATIC_MASK%
echo   Default Gateway: %STATIC_GATEWAY%
echo   Preferred DNS:   %DNS1%
echo   Alternate DNS:   %DNS2%
echo.

choice /C YN /N /M "Apply these settings? [Y/N]: "
if errorlevel 2 goto MENU
if errorlevel 1 goto APPLY_STATIC

:APPLY_STATIC
echo.
echo Applying static IP settings, please wait...

netsh interface ip set address name="%ConnectionName%" static %STATIC_IP% %STATIC_MASK% %STATIC_GATEWAY% 1
netsh interface ip set dns name="%ConnectionName%" static %DNS1% primary
netsh interface ip add dns name="%ConnectionName%" %DNS2% index=2

echo.
echo Static IP has been applied successfully!
echo.
pause
goto MENU

:SET_DHCP
cls
echo ==================================================
echo           Switch to DHCP (auto)
echo ==================================================
echo.

choice /C YN /N /M "Set %ConnectionName% to obtain IP automatically (DHCP)? [Y/N]: "
if errorlevel 2 goto MENU
if errorlevel 1 goto APPLY_DHCP

:APPLY_DHCP
echo.
echo Switching to DHCP, please wait...

netsh interface ip set address name="%ConnectionName%" dhcp
netsh interface ip set dns name="%ConnectionName%" dhcp

echo.
echo Successfully switched to DHCP (automatic IP)!
echo.
pause
goto MENU

:SHOW_IP
cls
echo ==================================================
echo           Current IP Configuration
echo ==================================================
echo.

echo (Note: on a Chinese-language Windows, some labels below may show in Chinese - that is normal)
echo.
ipconfig /all

echo.
pause
goto MENU

:FLUSH_DNS
cls
echo ==================================================
echo              Flush DNS Cache
echo ==================================================
echo.

ipconfig /flushdns

echo.
echo DNS cache has been flushed!
echo.
pause
goto MENU

:EXIT
cls
echo ==================================================
echo        Thank you for using WiFi IP Switch Tool
echo ==================================================
echo.
exit /b 0
