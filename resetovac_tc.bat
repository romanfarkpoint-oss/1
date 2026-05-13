@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "TC_PATH=P:\Programy\Totalcmd\TOTALCMD64.EXE"

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  if /i "%~1"=="--admin" exit /b 1
  echo [INFO] Script bude pokracovat v elevovanem okne.
  echo [INFO] Stiskni ENTER pro pokracovani...
  set /p "_go=>"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:ComSpec -ArgumentList '/c ""%~f0"" --admin' -Verb RunAs" >nul 2>&1
  exit /b
)

:: TVRDE ukonceni TC (vsechny varianty)
taskkill /f /t /im TOTALCMD64.EXE >nul 2>&1
taskkill /f /t /im TOTALCMD.EXE >nul 2>&1
taskkill /f /t /im totalcmd64.exe >nul 2>&1
taskkill /f /t /im totalcmd.exe >nul 2>&1

:: opakovane pokusy + kontrola
for /l %%I in (1,1,8) do (
  tasklist | find /i "TOTALCMD64.EXE" >nul && taskkill /f /t /im TOTALCMD64.EXE >nul 2>&1
  tasklist | find /i "TOTALCMD.EXE" >nul && taskkill /f /t /im TOTALCMD.EXE >nul 2>&1
  timeout /t 1 >nul
)

:: reset
rmdir /s /q "C:\ProgramData\TC_ConfigDeploy" >nul 2>&1
reg delete "HKLM\Software\Microsoft\Active Setup\Installed Components\{8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}" /f >nul 2>&1
rmdir /s /q "C:\Users\R\AppData\Roaming\GHISLER" >nul 2>&1
rmdir /s /q "C:\Users\L\AppData\Roaming\GHISLER" >nul 2>&1
rmdir /s /q "%APPDATA%\GHISLER" >nul 2>&1
reg delete "HKCU\Software\Microsoft\Active Setup\Installed Components\{8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}" /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" /v 1806 /t REG_DWORD /d 1 /f >nul 2>&1

if exist "%TEMP%\" del /f /q "%TEMP%\*" >nul 2>&1
if exist "C:\Windows\Temp\" del /f /q "C:\Windows\Temp\*" >nul 2>&1

taskkill /f /im explorer.exe >nul 2>&1
timeout /t 1 >nul
start explorer.exe

:: start TC
if exist "%TC_PATH%" start "" "%TC_PATH%"
if not exist "%TC_PATH%" (
  if exist "C:\Program Files\totalcmd\TOTALCMD64.EXE" start "" "C:\Program Files\totalcmd\TOTALCMD64.EXE"
)

exit /b
