@echo off
setlocal enabledelayedexpansion

rem ===== Config =====
set "PROFILE=Default"
set "BACKUP_ROOT=D:\EdgeBackup"
rem ==================

set "SRC=%LocalAppData%\Microsoft\Edge\User Data\%PROFILE%"

:menu
echo.
echo ===== Edge Extension Backup / Restore =====
echo Profile     : %PROFILE%
echo Backup root : %BACKUP_ROOT%
echo.
echo   1. Backup - new timestamped folder every time, cache excluded
echo   2. Restore extensions only - keeps current bookmarks, recommended
echo   3. Full restore - bookmarks/history also roll back
echo   0. Exit
echo.
set "CHOICE="
set /p CHOICE=Select 0-3: 
if "%CHOICE%"=="1" goto backup
if "%CHOICE%"=="2" goto restore_ext
if "%CHOICE%"=="3" goto restore_full
if "%CHOICE%"=="0" goto end
goto menu

:killedge
echo.
echo Closing Edge ...
taskkill /F /IM msedge.exe >nul 2>&1
timeout /t 2 /nobreak >nul
exit /b 0

:getts
for /f %%i in ('powershell -nologo -command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%i"
exit /b 0

:backup
call :killedge
if not exist "%SRC%" goto nosrc
call :getts
set "DEST=%BACKUP_ROOT%\%PROFILE%_backup_%TS%"
echo Backing up to %DEST% ...
robocopy "%SRC%" "%DEST%" /E /XD "Cache" "Code Cache" "GPUCache" "Service Worker" /R:1 /W:1 /NFL /NDL /NP
if errorlevel 8 goto robofail
echo Backup done: %DEST%
goto menu

:nosrc
echo ERROR: profile folder not found: %SRC%
goto menu

:robofail
echo robocopy reported errors, see output above.
goto menu

:pick
set "N=0"
for /f "delims=" %%d in ('dir /b /ad /o-n "%BACKUP_ROOT%" 2^>nul ^| findstr /b /i /c:"%PROFILE%" ^| findstr /v /i /c:"before_restore"') do call :addlist "%%d"
if "%N%"=="0" goto nobak
echo.
echo Available backups, newest first:
for /l %%i in (1,1,%N%) do echo   %%i. !ITEM_%%i!
set "PICK="
set /p PICK=Pick a number, Enter = 1: 
if "%PICK%"=="" set "PICK=1"
if not defined ITEM_%PICK% goto badpick
set "BAK=%BACKUP_ROOT%\!ITEM_%PICK%!"
echo Using: %BAK%
exit /b 0

:addlist
set /a N+=1
set "ITEM_%N%=%~1"
exit /b 0

:nobak
echo ERROR: no backup found in %BACKUP_ROOT%
exit /b 1

:badpick
echo Invalid number.
exit /b 1

:presave
call :getts
set "PRE=%BACKUP_ROOT%\%PROFILE%_before_restore_%TS%"
echo Saving current state to %PRE% ...
robocopy "%SRC%" "%PRE%" /E /XD "Cache" "Code Cache" "GPUCache" "Service Worker" /R:1 /W:1 /NFL /NDL /NP >nul
exit /b 0

:restore_ext
call :pick
if errorlevel 1 goto menu
call :killedge
call :presave
echo Restoring extension data ...
for %%D in ("Extensions" "Local Extension Settings" "Sync Extension Settings" "Extension State" "Extension Rules" "Extension Scripts" "IndexedDB" "Local Storage") do call :copydir "%%~D"
for %%F in ("Preferences" "Secure Preferences") do call :copyfile "%%~F"
echo.
echo Done. Open edge://extensions to check.
goto menu

:copydir
if not exist "%BAK%\%~1" goto skipdir
robocopy "%BAK%\%~1" "%SRC%\%~1" /E /R:1 /W:1 /NFL /NDL /NP >nul
echo   restored %~1
exit /b 0
:skipdir
echo   not in backup, skipped: %~1
exit /b 0

:copyfile
if not exist "%BAK%\%~1" goto skipfile
copy /Y "%BAK%\%~1" "%SRC%\%~1" >nul
echo   restored %~1
exit /b 0
:skipfile
echo   not in backup, skipped: %~1
exit /b 0

:restore_full
call :pick
if errorlevel 1 goto menu
echo.
echo WARNING: full restore rolls bookmarks/history/passwords back to the backup state.
set "SURE="
set /p SURE=Continue? Y/N: 
if /i not "%SURE%"=="Y" goto menu
call :killedge
call :presave
echo Restoring ...
robocopy "%BAK%" "%SRC%" /E /R:1 /W:1 /NFL /NDL /NP
if errorlevel 8 goto robofail
echo Full restore done. Open edge://extensions to check.
goto menu

:end
endlocal
exit /b 0
