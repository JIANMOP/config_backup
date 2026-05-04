
@echo off
title 帽帽电脑专用IP设置工具-增强版
color 0A

:: IP地址设置工具 - 增强版
:: 功能：交互式设置网络连接的IP地址配置
:: 注意：需要管理员权限运行

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 错误：此脚本需要管理员权限才能运行。
    echo 请右键点击脚本，选择"以管理员身份运行"。
    pause
    exit /b 1
)

:: 定义网络连接名称（请根据实际情况修改）
set "ConnectionName=WLAN"

:: 检查网络连接是否存在
netsh interface show interface | find "%ConnectionName%" >nul
if %errorlevel% neq 0 (
    echo 错误：未找到名为 "%ConnectionName%" 的网络连接。
    echo 请修改脚本中的 ConnectionName 变量为正确的网络连接名称。
    pause
    exit /b 1
)

:MENU
cls
echo ==================================================
echo           IP地址设置工具 - 增强版
echo ==================================================
echo.
echo  当前网络连接: %ConnectionName%
echo.
echo  1. 设置静态IP地址
echo  2. 设置为自动获取IP地址
echo  3. 显示当前IP配置
echo  4. 刷新DNS缓存
echo  5. 退出
echo.
echo ==================================================
echo.

choice /C 12345 /N /M "请选择操作 [1-5]: "

if errorlevel 5 goto EXIT
if errorlevel 4 goto FLUSH_DNS
if errorlevel 3 goto SHOW_IP
if errorlevel 2 goto SET_DHCP
if errorlevel 1 goto SET_STATIC_IP

:SET_STATIC_IP
cls
echo ==================================================
echo               设置静态IP地址
echo ==================================================
echo.

:INPUT_IP
set /p ip="请输入IP地址 [例如: 192.168.1.100]: "
call :VALIDATE_IP %ip%
if %errorlevel% neq 0 (
    echo 错误：无效的IP地址格式，请重新输入。
    goto INPUT_IP
)

:INPUT_MASK
set /p mask="请输入子网掩码 [例如: 255.255.255.0]: "
call :VALIDATE_MASK %mask%
if %errorlevel% neq 0 (
    echo 错误：无效的子网掩码格式，请重新输入。
    goto INPUT_MASK
)

:INPUT_GATEWAY
set /p gateway="请输入默认网关 [例如: 192.168.1.1]: "
if not "%gateway%"=="" (
    call :VALIDATE_IP %gateway%
    if %errorlevel% neq 0 (
        echo 错误：无效的默认网关格式，请重新输入。
        goto INPUT_GATEWAY
    )
)

:INPUT_DNS1
set /p dns1="请输入首选DNS服务器 [例如: 8.8.8.8]: "
if not "%dns1%"=="" (
    call :VALIDATE_IP %dns1%
    if %errorlevel% neq 0 (
        echo 错误：无效的DNS服务器格式，请重新输入。
        goto INPUT_DNS1
    )
)

:INPUT_DNS2
set /p dns2="请输入备用DNS服务器 [例如: 8.8.4.4]: (留空则不设置) "
if not "%dns2%"=="" (
    call :VALIDATE_IP %dns2%
    if %errorlevel% neq 0 (
        echo 错误：无效的DNS服务器格式，请重新输入。
        goto INPUT_DNS2
    )
)

echo.
echo 确认设置:
echo.
echo   IP地址:       %ip%
echo   子网掩码:     %mask%
echo   默认网关:     %gateway%
echo   首选DNS:      %dns1%
echo   备用DNS:      %dns2%
echo.

choice /C YN /N /M "是否应用上述设置? [Y/N]: "
if errorlevel 2 goto MENU
if errorlevel 1 goto APPLY_STATIC

:APPLY_STATIC
echo.
echo 正在设置IP地址，请稍候...

:: 设置IP地址和子网掩码
netsh interface ip set address name="%ConnectionName%" static %ip% %mask% %gateway% 1

:: 设置DNS服务器
if not "%dns1%"=="" (
    netsh interface ip set dns name="%ConnectionName%" static %dns1% primary
) else (
    netsh interface ip set dns name="%ConnectionName%" dhcp
)

if not "%dns2%"=="" (
    netsh interface ip add dns name="%ConnectionName%" %dns2% index=2
)

echo.
echo IP地址设置完成！
echo.
pause
goto MENU

:SET_DHCP
cls
echo ==================================================
echo             设置为自动获取IP地址
echo ==================================================
echo.

choice /C YN /N /M "确定要将 %ConnectionName% 设置为自动获取IP地址吗? [Y/N]: "
if errorlevel 2 goto MENU
if errorlevel 1 goto APPLY_DHCP

:APPLY_DHCP
echo.
echo 正在设置为自动获取IP地址，请稍候...

:: 设置为自动获取IP地址
netsh interface ip set address name="%ConnectionName%" dhcp

:: 设置为自动获取DNS服务器
netsh interface ip set dns name="%ConnectionName%" dhcp

echo.
echo 已成功设置为自动获取IP地址！
echo.
pause
goto MENU

:SHOW_IP
cls
echo ==================================================
echo              当前IP配置信息
echo ==================================================
echo.

ipconfig /all | findstr /i /c:"%ConnectionName%" /c:"IPv4" /c:"子网掩码" /c:"默认网关" /c:"DNS服务器"

echo.
pause
goto MENU

:FLUSH_DNS
cls
echo ==================================================
echo                刷新DNS缓存
echo ==================================================
echo.

ipconfig /flushdns

echo.
echo DNS缓存已刷新！
echo.
pause
goto MENU

:EXIT
cls
echo ==================================================
echo                感谢使用IP设置工具
echo ==================================================
echo.
exit /b 0

:VALIDATE_IP
:: 验证IP地址格式
set "ip=%~1"
set "octets=0"
set "valid=1"

:: 检查是否有4个点分十进制部分
for /f "tokens=1-4 delims=." %%a in ("%ip%") do (
    set /a octets+=1
    set "octet=%%a"

    :: 检查每个部分是否为数字
    for /f "delims=0123456789" %%i in ("!octet!") do set "valid=0"

    :: 检查每个部分是否在0-255之间
    if !octet! LSS 0 set "valid=0"
    if !octet! GTR 255 set "valid=0"
)

:: 检查是否正好有4个部分
if %octets% neq 4 set "valid=0"

exit /b %valid%

:VALIDATE_MASK
:: 验证子网掩码格式
set "mask=%~1"
call :VALIDATE_IP %mask%
if errorlevel 1 exit /b 1

:: 检查是否为有效的子网掩码值
set "valid_masks=255.0.0.0 255.128.0.0 255.192.0.0 255.224.0.0 255.240.0.0 255.248.0.0 255.252.0.0 255.254.0.0 255.255.0.0 255.255.128.0 255.255.192.0 255.255.224.0 255.255.240.0 255.255.248.0 255.255.252.0 255.255.254.0 255.255.255.0 255.255.255.128 255.255.255.192 255.255.255.224 255.255.255.240 255.255.255.248 255.255.255.252"

for %%m in (%valid_masks%) do (
    if "%mask%"=="%%m" exit /b 0
)

exit /b 1