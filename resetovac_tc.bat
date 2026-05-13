@echo off
setlocal EnableExtensions

set "LOG_DIR=%ProgramData%\TC_ResetState"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
set "LOG=%LOG_DIR%\log.txt"

>>"%LOG%" echo.
>>"%LOG%" echo ===== START %DATE% %TIME% =====
>>"%LOG%" echo [INFO] Script: %~f0

:: Elevation
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    if /i "%~1"=="--admin" (
        echo [CHYBA] Nelze ziskat admin prava.
        >>"%LOG%" echo [ERROR] Nelze ziskat admin prava.
        pause
        exit /b 1
    )
    echo [INFO] Spoustim znovu jako spravce...
    >>"%LOG%" echo [INFO] Spoustim znovu jako spravce...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:ComSpec -ArgumentList '/c ""%~fs0"" --admin' -Verb RunAs"
    exit /b
)

call :logrun rmdir /s /q "C:\ProgramData\TC_ConfigDeploy"
call :logrun reg delete "HKLM\Software\Microsoft\Active Setup\Installed Components\{8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}" /f

call :logrun rmdir /s /q "C:\Users\R\AppData\Roaming\GHISLER"
call :logrun rmdir /s /q "C:\Users\L\AppData\Roaming\GHISLER"

call :logrun reg delete "HKCU\Software\Microsoft\Active Setup\Installed Components\{8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}" /f
call :logrun reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" /v 1806 /t REG_DWORD /d 1 /f

if exist "%TEMP%\" (
    call :logrun del /f /s /q "%TEMP%\*"
    for /d %%D in ("%TEMP%\*") do call :logrun rd /s /q "%%~fD"
)
if exist "C:\Windows\Temp\" (
    call :logrun del /f /s /q "C:\Windows\Temp\*"
    for /d %%D in ("C:\Windows\Temp\*") do call :logrun rd /s /q "%%~fD"
)

call :logrun taskkill /f /im explorer.exe
timeout /t 2 >nul
start explorer.exe

>>"%LOG%" echo [OK] Dokonceno.
>>"%LOG%" echo ===== END %DATE% %TIME% =====
echo Hotovo. Log: %LOG%
pause
exit /b

:logrun
>>"%LOG%" echo [CMD] %*
%* >>"%LOG%" 2>&1
>>"%LOG%" echo [RC] %errorlevel%
exit /b
