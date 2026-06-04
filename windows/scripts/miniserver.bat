@echo off
setlocal enabledelayedexpansion

REM --- find miniserve -----------------------------------------
miniserve --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] miniserve not found. Check PATH or reinstall.
    exit /b 1
)

echo.
echo --- miniserve quick launch ---
echo.

REM --- 1. Path -------------------------------------------------
set /p RAW_PATH="   Path to serve (default: current dir) [.]: "
if "!RAW_PATH!"=="" set RAW_PATH=.
echo    ^> !RAW_PATH!
echo.

REM --- 2. Port -------------------------------------------------
set /p PORT="   Port [8080]: "
if "!PORT!"=="" set PORT=8080
echo.

REM --- 3. Feature toggles --------------------------------------
set /p UPLOAD="   Enable file uploads y/[n]: "
set /p MKDIR="   Allow creating directories y/[n]: "
set /p TARGZ="   Enable tar.gz download y/[n]: "
set /p ZIP="   Enable zip download y/[n]: "
set /p QR="   Show QR code in terminal y/[n]: "
echo.

REM --- 4. Build args ------------------------------------------
set ARGS=-p !PORT!
if /i "!UPLOAD!"=="y" set ARGS=!ARGS! -u
if /i "!MKDIR!"=="y"  set ARGS=!ARGS! -U
if /i "!TARGZ!"=="y"  set ARGS=!ARGS! -g
if /i "!ZIP!"=="y"    set ARGS=!ARGS! -z
if /i "!QR!"=="y"     set ARGS=!ARGS! -q

REM --- 5. Preview & confirm ------------------------------------
echo --- Command preview ---
echo.
echo    miniserve !ARGS! "!RAW_PATH!"
echo.
set /p CONFIRM="   Launch now? [y]/n: "
if /i "!CONFIRM!"=="n" (
    echo    Cancelled
    exit /b 0
)
if /i "!CONFIRM!"=="no" (
    echo    Cancelled
    exit /b 0
)

echo.
echo    Starting... Ctrl+C to stop
echo.
miniserve %ARGS% "%RAW_PATH%"
