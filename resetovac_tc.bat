@echo off
setlocal EnableExtensions

set "LOG_DIR=%ProgramData%\TC_ResetState"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
set "LOG=%LOG_DIR%\log.txt"

echo.>>"%LOG%"
echo ===== START %DATE% %TIME% =====>>"%LOG%"
echo [INFO] Script: %~f0>>"%LOG%"

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  if /i "%~1"=="--admin" (
    echo [ERROR] UAC probehl, ale stale bez admin prav.>>"%LOG%"
    echo [CHYBA] Nepodarilo se ziskat admin prava.
    echo Log: %LOG%
    pause
    exit /b 1
  )
  echo [INFO] Spoustim znovu jako spravce...
  echo [INFO] Spoustim znovu jako spravce...>>"%LOG%"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:ComSpec -ArgumentList '/c ""%~fs0"" --admin' -Verb RunAs" >nul 2>&1
  exit /b
)

call :run "rmdir /s /q \"C:\ProgramData\TC_ConfigDeploy\""
call :run "reg delete \"HKLM\Software\Microsoft\Active Setup\Installed Components\{8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}\" /f"

call :cleanup_user "R"
call :cleanup_user "L"
call :cleanup_current_hkcu
call :clean_temp
call :run "taskkill /f /im explorer.exe"
timeout /t 2 >nul
start explorer.exe

echo [OK] Dokonceno.>>"%LOG%"
echo ===== END %DATE% %TIME% =====>>"%LOG%"
echo Hotovo. Log: %LOG%
pause
exit /b

:cleanup_user
set "U=%~1"
if "%U%"=="" exit /b
call :run "rmdir /s /q \"C:\Users\%U%\AppData\Roaming\GHISLER\""
exit /b

:cleanup_current_hkcu
call :run "reg delete \"HKCU\Software\Microsoft\Active Setup\Installed Components\{8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}\" /f"
call :run "reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3\" /v 1806 /t REG_DWORD /d 1 /f"
exit /b

:clean_temp
if exist "%TEMP%\" (
  call :run "del /f /s /q \"%TEMP%\*\""
  call :run "for /d %%D in (\"%TEMP%\*\") do rd /s /q \"%%~fD\""
)
if exist "C:\Windows\Temp\" (
  call :run "del /f /s /q \"C:\Windows\Temp\*\""
  call :run "for /d %%D in (\"C:\Windows\Temp\*\") do rd /s /q \"%%~fD\""
)
exit /b

:run
set "CMD=%~1"
echo [CMD] %CMD%>>"%LOG%"
cmd /c %CMD% >>"%LOG%" 2>&1
echo [RC] %errorlevel%>>"%LOG%"
exit /b
