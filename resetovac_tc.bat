@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ------------------------------------------------------------
:: RESETOVACI SKRIPT TC + Active Setup + TEMP + Explorer reset
:: ------------------------------------------------------------

:: Self-elevation to Administrator
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo [INFO] Spoustim znovu jako spravce...
    set "ELEVATED_COPY=%ProgramData%\resetovac_tc_elevated.bat"
    copy /y "%~f0" "%ELEVATED_COPY%" >nul
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/k ""%ELEVATED_COPY%"" --elevated' -Verb RunAs"
    exit /b
)

if /i "%~1"=="--elevated" shift

set "LOG=%~dp0reset_log_%DATE:~-4%%DATE:~3,2%%DATE:~0,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.txt"
set "LOG=%LOG: =0%"
if not exist "%~dp0" set "LOG=%SystemDrive%\reset_log_fallback.txt"

echo ===== RESET START %DATE% %TIME% ===== > "%LOG%"

echo [1/6] Mazu TC system deploy + Active Setup...
call :run "rmdir /s /q \"C:\ProgramData\TC_ConfigDeploy\""
call :run "reg delete \"HKLM\Software\Microsoft\Active Setup\Installed Components\{8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}\" /f"

echo [2/6] Mazu TC konfiguraci uzivatelu R a L...
call :run "rmdir /s /q \"C:\Users\R\AppData\Roaming\GHISLER\""
call :run "rmdir /s /q \"C:\Users\L\AppData\Roaming\GHISLER\""

echo [3/6] Mazu HKCU Active Setup aktualniho uzivatele...
call :run "reg delete \"HKCU\Software\Microsoft\Active Setup\Installed Components\{8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}\" /f"

echo [4/6] Cistim TEMP...
if exist "%TEMP%\" (
    call :run "del /f /s /q \"%TEMP%\*\""
    call :run "for /d %%D in (\"%TEMP%\*\") do rd /s /q \"%%~fD\""
) else (
    echo [WARN] TEMP neexistuje: %TEMP%>>"%LOG%"
)
if exist "C:\Windows\Temp\" (
    call :run "del /f /s /q \"C:\Windows\Temp\*\""
    call :run "for /d %%D in (\"C:\Windows\Temp\*\") do rd /s /q \"%%~fD\""
) else (
    echo [WARN] C:\Windows\Temp neexistuje>>"%LOG%"
)

echo [5/6] Restartuji Explorer (zavre otevrena okna Pruzkumnika)...
call :run "taskkill /f /im explorer.exe"
timeout /t 2 >nul
start explorer.exe

echo [6/6] Signal pro druheho uzivatele + odhlaseni...
for /f "skip=1 tokens=3" %%S in ('query user 2^>nul ^| findstr /i " R  L "') do (
    if not "%%S"=="" set "TARGET_SESSION=%%S"
)
if defined TARGET_SESSION (
    msg * /time:120 "Mazani TC/GHISLER probehlo. Potvrdte Enter v administratorskem okne. Pak bude uzivatel odhlasen."
) else (
    echo [INFO] Nenasel jsem aktivni session R/L. Preskakuji vzdaleny signal.>>"%LOG%"
)

echo.
echo Mazani probehlo. Stiskni ENTER pro odhlaseni druheho uzivatele (pokud je prihlaseny).
set /p "_go=> "
if defined TARGET_SESSION (
    call :run "logoff !TARGET_SESSION!"
)

echo.
echo HOTOVO. Vysledek je v logu:
echo %LOG%
echo ===== RESET END %DATE% %TIME% =====>>"%LOG%"
if exist "%ProgramData%\resetovac_tc_elevated.bat" del /q "%ProgramData%\resetovac_tc_elevated.bat" >nul 2>&1
pause
exit /b

:run
set "CMD=%~1"
echo [CMD] %CMD%>>"%LOG%"
cmd /c %CMD% >>"%LOG%" 2>&1
echo [RC ] !errorlevel!>>"%LOG%"
exit /b
