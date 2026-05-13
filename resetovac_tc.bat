@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: RESET TC + dvouuzivatelsky rezim (R/L)

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo [INFO] Spoustim znovu jako spravce...
  set "ELEVATED_COPY=%ProgramData%\resetovac_tc_elevated.bat"
  copy /y "%~f0" "%ELEVATED_COPY%" >nul
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/k ""%ELEVATED_COPY%"" --elevated' -Verb RunAs"
  exit /b
)
if /i "%~1"=="--elevated" shift

set "CURRENT_USER=%USERNAME%"
set "CURRENT_USER=%CURRENT_USER: =%"
set "OTHER_USER="
if /i "%CURRENT_USER%"=="R" set "OTHER_USER=L"
if /i "%CURRENT_USER%"=="L" set "OTHER_USER=R"

set "LOG=%~dp0reset_log_%DATE:~-4%%DATE:~3,2%%DATE:~0,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.txt"
set "LOG=%LOG: =0%"
if not exist "%~dp0" set "LOG=%SystemDrive%\reset_log_fallback.txt"

echo ===== RESET START %DATE% %TIME% ===== > "%LOG%"
echo [INFO] Aktualni uzivatel: %CURRENT_USER%>>"%LOG%"
echo [INFO] Druhy uzivatel: %OTHER_USER%>>"%LOG%"

:: SYSTEM cast - jen jednou
call :run "rmdir /s /q \"C:\ProgramData\TC_ConfigDeploy\""
call :run "reg delete \"HKLM\Software\Microsoft\Active Setup\Installed Components\{8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}\" /f"

:: AKTUALNI uzivatel
call :cleanup_user "%CURRENT_USER%"

:: DRUHY uzivatel - pokus o viditelnou informaci jen jemu
if defined OTHER_USER (
  call :find_session "%OTHER_USER%"
  if defined TARGET_SESSION (
    msg %OTHER_USER% /time:120 "RESET TC: prihlas se, otevri CMD a spust resetovac_tc.bat. Po dokonceni se odhlas."
    echo [INFO] Odeslana zprava uzivateli %OTHER_USER% (session !TARGET_SESSION!).>>"%LOG%"
  ) else (
    echo [INFO] Uzivatel %OTHER_USER% nema aktivni session.>>"%LOG%"
  )
)

echo.
echo ==============================================
echo KROK PRO DRUHEHO UZIVATELE (%OTHER_USER%):
echo 1) Prepnout na nej.
echo 2) Spustit tento stejny resetovac_tc.bat (jako spravce).
echo 3) Po dokonceni ho odhlasit.
echo 4) Vratit se sem a stisknout ENTER.
echo ==============================================
pause

:: Bezpecnost: nikdy neodhlasuj aktualniho uzivatele
if defined OTHER_USER (
  call :find_session "%OTHER_USER%"
  if defined TARGET_SESSION (
    call :run "logoff !TARGET_SESSION!"
  ) else (
    echo [INFO] Druhy uzivatel uz odhlasen nebo nenalezen.>>"%LOG%"
  )
)

call :clean_temp
call :run "taskkill /f /im explorer.exe"
timeout /t 2 >nul
start explorer.exe

echo ===== RESET END %DATE% %TIME% =====>>"%LOG%"
if exist "%ProgramData%\resetovac_tc_elevated.bat" del /q "%ProgramData%\resetovac_tc_elevated.bat" >nul 2>&1

echo HOTOVO. Log: %LOG%
pause
exit /b

:cleanup_user
set "U=%~1"
if "%U%"=="" exit /b
call :run "rmdir /s /q \"C:\Users\%U%\AppData\Roaming\GHISLER\""
if /i "%U%"=="%USERNAME%" (
  call :run "reg delete \"HKCU\Software\Microsoft\Active Setup\Installed Components\{8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}\" /f"
)
exit /b

:find_session
set "TARGET_SESSION="
for /f "skip=1 tokens=1,3" %%A in ('query user 2^>nul') do (
  if /i "%%A"=="%~1" set "TARGET_SESSION=%%B"
)
if defined TARGET_SESSION if "!TARGET_SESSION!"=="Active" set "TARGET_SESSION="
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
echo [RC ] !errorlevel!>>"%LOG%"
exit /b
