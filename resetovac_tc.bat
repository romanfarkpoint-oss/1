@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "LOG_DIR=C:\log"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
set "LOG=%LOG_DIR%\log.txt"

:: vzdy novy kompletni log
>"%LOG%" echo ===== START %DATE% %TIME% =====
>>"%LOG%" echo [INFO] Script: %~f0

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  if /i "%~1"=="--admin" (
    >>"%LOG%" echo [ERROR] Nepodarilo se ziskat admin prava.
    echo [CHYBA] Nepodarilo se ziskat admin prava.
    exit /b 1
  )
  echo [INFO] Script bude pokracovat v elevovanem okne.
  echo [INFO] Stiskni ENTER pro pokracovani...
  set /p "_go=>"
  >>"%LOG%" echo [INFO] Spoustim znovu jako spravce...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:ComSpec -ArgumentList '/c ""%~f0"" --admin' -Verb RunAs" >nul 2>&1
  exit /b
)

:: 1) zavrit TC spolehlive
call :logrun taskkill /f /im TOTALCMD64.EXE
call :logrun taskkill /f /im TOTALCMD.EXE
for /l %%I in (1,1,5) do (
  tasklist | find /i "TOTALCMD64.EXE" >nul && call :logrun taskkill /f /im TOTALCMD64.EXE
  tasklist | find /i "TOTALCMD.EXE" >nul && call :logrun taskkill /f /im TOTALCMD.EXE
  timeout /t 1 >nul
)

:: 2) reset
call :logrun rmdir /s /q "C:\ProgramData\TC_ConfigDeploy"
call :logrun reg delete "HKLM\Software\Microsoft\Active Setup\Installed Components\{8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}" /f
call :logrun rmdir /s /q "C:\Users\R\AppData\Roaming\GHISLER"
call :logrun rmdir /s /q "C:\Users\L\AppData\Roaming\GHISLER"
call :logrun rmdir /s /q "%APPDATA%\GHISLER"
call :logrun reg delete "HKCU\Software\Microsoft\Active Setup\Installed Components\{8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}" /f
call :logrun reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" /v 1806 /t REG_DWORD /d 1 /f

:: 3) rychly temp cleanup
if exist "%TEMP%\" call :logrun del /f /q "%TEMP%\*"
if exist "C:\Windows\Temp\" call :logrun del /f /q "C:\Windows\Temp\*"

:: 4) explorer restart
call :logrun taskkill /f /im explorer.exe
timeout /t 1 >nul
start explorer.exe

:: 5) znovu spustit TC
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
set "TC_EXE="
for /f "skip=2 tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\TOTALCMD64.EXE" /ve 2^>nul') do set "TC_EXE=%%B"
if not defined TC_EXE for /f "skip=2 tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\TOTALCMD.EXE" /ve 2^>nul') do set "TC_EXE=%%B"
if not defined TC_EXE if exist "C:\Program Files\totalcmd\TOTALCMD64.EXE" set "TC_EXE=C:\Program Files\totalcmd\TOTALCMD64.EXE"
if not defined TC_EXE if exist "C:\Program Files\totalcmd\TOTALCMD.EXE" set "TC_EXE=C:\Program Files\totalcmd\TOTALCMD.EXE"
if not defined TC_EXE if exist "C:\totalcmd\TOTALCMD64.EXE" set "TC_EXE=C:\totalcmd\TOTALCMD64.EXE"
if not defined TC_EXE if exist "C:\totalcmd\TOTALCMD.EXE" set "TC_EXE=C:\totalcmd\TOTALCMD.EXE"
if defined TC_EXE (
  >>"%LOG%" echo [INFO] Spoustim TC: !TC_EXE!
  start "" "!TC_EXE!"
) else (
  >>"%LOG%" echo [WARN] TC nenalezen pro automaticke spusteni.
)
exit /b
