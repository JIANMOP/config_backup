@echo off
:: 确保以管理员权限运行
:: 清理电脑垃圾
title 清理电脑垃圾
color  0a
fltmc >nul 2>&1 || (echo 请以管理员身份运行此脚本！ & pause >nul & exit /b 1)
echo ==============================================
echo           系统全面垃圾清理工具
echo ==============================================
echo 正在清理系统垃圾文件，请稍候...
echo 清理过程中出现的"文件正在使用"提示属于正常现象
:: 等待2秒，让用户看到提示
ping -n 2 127.0.0.1 >nul
:: 清理系统临时文件夹
del /f /s /q %windir%\Temp\*.* >nul 2>&1rd /s /q %windir%\Temp >nul 2>&1md %windir%\Temp >nul 2>&1
:: 清理系统预读文件
del /f /s /q %windir%\Prefetch\*.* >nul 2>&1
:: 清理用户临时文件
del /f /s /q %userprofile%\AppData\Local\Temp\*.* >nul 2>&1rd /s /q %userprofile%\AppData\Local\Temp\*.* >nul 2>&1
:: 清理IE浏览器缓存
del /f /s /q "%userprofile%\AppData\Local\Microsoft\Windows\INetCache\*.*" >nul 2>&1
:: 清理Chrome浏览器缓存
del /f /s /q "%userprofile%\AppData\Local\Google\Chrome\User Data\Default\Cache\*.*" >nul 2>&1del /f /s /q "%userprofile%\AppData\Local\Google\Chrome\User Data\Default\Cookies" >nul 2>&1del /f /s /q "%userprofile%\AppData\Local\Google\Chrome\User Data\Default\History" >nul 2>&1
:: 清理Firefox浏览器缓存
del /f /s /q "%userprofile%\AppData\Roaming\Mozilla\Firefox\Profiles\*\Cache\*.*" >nul 2>&1del /f /s /q "%userprofile%\AppData\Roaming\Mozilla\Firefox\Profiles\*\.parentlock" >nul 2>&1
:: 清理Edge浏览器缓存
del /f /s /q "%userprofile%\AppData\Local\Microsoft\Edge\User Data\Default\Cache\*.*" >nul 2>&1
:: 清理系统更新残留文件
del /f /s /q %windir%\SoftwareDistribution\Download\*.* >nul 2>&1
:: 清理系统日志文件
del /f /s /q %windir%\Logs\*.* >nul 2>&1del /f /s /q %windir%\System32\LogFiles\*.* >nul 2>&1
:: 清理回收站（所有驱动器）
for /d %%d in (C:,D:,E:,F:,G:) do (    if exist "%%d\$Recycle.Bin\" (        rd /s /q "%%d\$Recycle.Bin\" >nul 2>&1    ))
:: 清理缩略图缓存
del /f /s /q "%userprofile%\AppData\Local\Microsoft\Windows\Explorer\*_thumbcache.db" >nul 2>&1
:: 清理最近访问记录
:: del /f /s /q "%userprofile%\AppData\Roaming\Microsoft\Windows\Recent\*.*" >nul 2>&1rd /s /q "%userprofile%\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations" >nul 2>&1md "%userprofile%\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations" >nul 2>&1
:: 清理Windows错误报告
del /f /s /q "%userprofile%\AppData\Local\Microsoft\Windows\WER\*.*" >nul 2>&1del /f /s /q "%allusersprofile%\Microsoft\Windows\WER\*.*" >nul 2>&1
:: 清理Java缓存
del /f /s /q "%userprofile%\AppData\LocalLow\Sun\Java\Deployment\cache\*.*" >nul 2>&1
echo.
echo ==============================================
echo           垃圾清理完成！
echo ==============================================
echo 已清理的项目包括：
echo - 系统临时文件和预读文件
echo - 主流浏览器缓存（IE/Chrome/Firefox/Edge）
echo - 系统更新残留文件和日志
echo - 回收站文件（所有驱动器）
echo - 缩略图缓存和最近访问记录
echo - Windows错误报告和Java缓存
echo.
echo 建议重启计算机以完全释放系统资源
pause >nul