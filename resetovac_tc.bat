@echo off
setlocal EnableExtensions

set "REQ_LOG_DIR=P:\Programy\zSkripty\AHK\Já"
set "LOG_DIR=%ProgramData%\TC_ResetState"
if exist "%REQ_LOG_DIR%\" (
  for %%I in ("%REQ_LOG_DIR%") do set "LOG_DIR=%%~fI"
)
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
set "LOG=%LOG_DIR%\log.txt"

>>"%LOG%" echo.
>>"%LOG%" echo ===== START %DATE% %TIME% =====
>>"%LOG%" echo [INFO] Script: %~f0

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    if /i "%~1"=="--admin" (
        >>"%LOG%" echo [ERROR] Nelze ziskat admin prava.
        exit /b 1
    )
    >>"%LOG%" echo [INFO] Spoustim znovu jako spravce...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:ComSpec -ArgumentList '/c ""%~fs0"" --admin' -Verb RunAs" >nul 2>&1
    exit /b
)

:: 1) ukoncit vsechny Total Commandery
call :logrun taskkill /f /im TOTALCMD64.EXE
call :logrun taskkill /f /im TOTALCMD.EXE

:: 2) reset akce
call :logrun rmdir /s /q "C:\ProgramData\TC_ConfigDeploy"
call :logrun reg delete "HKLM\Software\Microsoft\Active Setup\Installed Components\{8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}" /f
call :logrun rmdir /s /q "C:\Users\R\AppData\Roaming\GHISLER"
call :logrun rmdir /s /q "C:\Users\L\AppData\Roaming\GHISLER"
call :logrun reg delete "HKCU\Software\Microsoft\Active Setup\Installed Components\{8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}" /f
call :logrun reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" /v 1806 /t REG_DWORD /d 1 /f

:: 3) mirnejsi temp cleanup - jen top-level soubory/slozky
if exist "%TEMP%\" (
    call :logrun del /f /q "%TEMP%\*"
    for /d %%D in ("%TEMP%\*") do call :logrun rd /s /q "%%~fD"
)
if exist "C:\Windows\Temp\" (
    call :logrun del /f /q "C:\Windows\Temp\*"
    for /d %%D in ("C:\Windows\Temp\*") do call :logrun rd /s /q "%%~fD"
)

:: 4) restart explorer
call :logrun taskkill /f /im explorer.exe
timeout /t 2 >nul
start explorer.exe

:: 5) znovu otevrit Total Commander (bez cekani)
call :start_tc

>>"%LOG%" echo [OK] Dokonceno.
>>"%LOG%" echo ===== END %DATE% %TIME% =====
exit /b

:logrun
>>"%LOG%" echo [CMD] %*
%* >>"%LOG%" 2>&1
>>"%LOG%" echo [RC] %errorlevel%
exit /b

:start_tc
if exist "C:\Program Files\totalcmd\TOTALCMD64.EXE" start "" "C:\Program Files\totalcmd\TOTALCMD64.EXE" & exit /b
if exist "C:\Program Files\totalcmd\TOTALCMD.EXE" start "" "C:\Program Files\totalcmd\TOTALCMD.EXE" & exit /b
if exist "C:\totalcmd\TOTALCMD64.EXE" start "" "C:\totalcmd\TOTALCMD64.EXE" & exit /b
if exist "C:\totalcmd\TOTALCMD.EXE" start "" "C:\totalcmd\TOTALCMD.EXE" & exit /b
if exist "P:\Programy\Total Commander\TOTALCMD64.EXE" start "" "P:\Programy\Total Commander\TOTALCMD64.EXE" & exit /b
if exist "P:\Programy\Total Commander\TOTALCMD.EXE" start "" "P:\Programy\Total Commander\TOTALCMD.EXE" & exit /b
>>"%LOG%" echo [WARN] Total Commander nebyl nalezen pro automaticke spusteni.
exit /b
