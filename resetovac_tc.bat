@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "PSEXEC=P:\Programy\zSkripty\Ostatni\PsExec.exe"
set "TC_GUID={8F7B99BB-8C5A-4E7B-9D7A-TC0000000001}"
set "MASTER_LOG=P:\Programy\zSkripty\AHK\Já\log.txt"
if not exist "P:\Programy\zSkripty\AHK\Já\" set "MASTER_LOG=%ProgramData%\TC_ResetState\log.txt"
if not exist "%ProgramData%\TC_ResetState" mkdir "%ProgramData%\TC_ResetState" >nul 2>&1

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo [INFO] Spoustim znovu jako spravce...
  echo [INFO] Spoustim znovu jako spravce...>>"%MASTER_LOG%"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c ""\"%~f0\" --elevated\"' -Verb RunAs" >nul 2>&1
  if errorlevel 1 (
    mshta "vbscript:CreateObject(""Shell.Application"").ShellExecute ""cmd.exe"", ""/c """"%~f0"""" --elevated"", """", ""runas"", 1 (close)"
  )
  exit /b
)
if /i "%~1"=="--elevated" shift

set "CURRENT_USER=%USERNAME%"
set "OTHER_USER="
if /i "%CURRENT_USER%"=="R" set "OTHER_USER=L"
if /i "%CURRENT_USER%"=="L" set "OTHER_USER=R"

set "LOG=%~dp0reset_log_%DATE:~-4%%DATE:~3,2%%DATE:~0,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%.txt"
set "LOG=%LOG: =0%"
if not exist "%~dp0" set "LOG=%SystemDrive%\reset_log_fallback.txt"

set "STATE_DIR=%ProgramData%\TC_ResetState"
if not exist "%STATE_DIR%" mkdir "%STATE_DIR%" >nul 2>&1
set "STATE_FILE=%STATE_DIR%\done_%OTHER_USER%.flag"
set "HAS_ERROR=0"

if /i "%~1"=="--second-phase" goto SECOND_PHASE

echo ===== RESET START (PHASE1) %DATE% %TIME% ===== > "%LOG%"
echo ===== RESET START (PHASE1) %DATE% %TIME% =====>>"%MASTER_LOG%"
echo [INFO] current=%CURRENT_USER% other=%OTHER_USER%>>"%LOG%"
echo [INFO] current=%CURRENT_USER% other=%OTHER_USER%>>"%MASTER_LOG%"

call :system_cleanup
call :cleanup_user "%CURRENT_USER%"

if not exist "%PSEXEC%" (
  echo [ERR] PsExec nenalezen: %PSEXEC%>>"%LOG%"
  echo PsExec nenalezen: %PSEXEC%
  goto END
)

call :find_session "%OTHER_USER%"
if not defined TARGET_SESSION (
  echo [ERR] Druhy uzivatel %OTHER_USER% neni prihlasen.>>"%LOG%"
  echo Druhy uzivatel %OTHER_USER% neni prihlasen. Prihlas ho a spust script znovu.
  goto END
)

del /q "%STATE_FILE%" >nul 2>&1

set "PHASE2_CMD=\"%~f0\" --elevated --second-phase"
call :run "\"%PSEXEC%\" -accepteula -i !TARGET_SESSION! -h cmd.exe /c %PHASE2_CMD%"

echo.
echo Cekam na dokonceni druheho uzivatele (%OTHER_USER%)...
:WAIT_SECOND
if exist "%STATE_FILE%" goto AFTER_SECOND
timeout /t 2 >nul
goto WAIT_SECOND

:AFTER_SECOND
echo [INFO] Druhy uzivatel dokoncil reset.>>"%LOG%"
call :run "logoff !TARGET_SESSION!"
call :clean_temp
call :run "taskkill /f /im explorer.exe"
timeout /t 2 >nul
start explorer.exe

if "%HAS_ERROR%"=="0" (
  echo [VYSLEDEK] Vse probehlo v poradku u obou uzivatelu.
  echo [RESULT] OK>>"%LOG%"
) else (
  echo [VYSLEDEK] Dokonceno s chybami - zkontroluj log: %LOG%
  echo [RESULT] ERROR>>"%LOG%"
)
goto END

:SECOND_PHASE
set "LOG=%~dp0reset_log_second_%USERNAME%_%DATE:~-4%%DATE:~3,2%%DATE:~0,2%.txt"
set "LOG=%LOG: =0%"
echo ===== RESET SECOND USER START %DATE% %TIME% ===== > "%LOG%"
echo ===== RESET SECOND USER START %DATE% %TIME% =====>>"%MASTER_LOG%"
echo Bezi faze pro druheho uzivatele: %USERNAME%
call :cleanup_user "%USERNAME%"
call :clean_temp
echo [OK] Mazani probehlo. Stiskni ENTER pro ukonceni a navrat na prvniho uzivatele.
set /p "_done=> "
>"%ProgramData%\TC_ResetState\done_%USERNAME%.flag" echo done %DATE% %TIME%
exit /b

:system_cleanup
call :run "rmdir /s /q \"C:\ProgramData\TC_ConfigDeploy\""
call :run "reg delete \"HKLM\Software\Microsoft\Active Setup\Installed Components\%TC_GUID%\" /f"
exit /b

:cleanup_user
set "U=%~1"
if "%U%"=="" exit /b
call :run "rmdir /s /q \"C:\Users\%U%\AppData\Roaming\GHISLER\""
if /i "%U%"=="%USERNAME%" (
  call :run "reg delete \"HKCU\Software\Microsoft\Active Setup\Installed Components\%TC_GUID%\" /f"
  call :run "reg add \"HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3\" /v 1806 /t REG_DWORD /d 1 /f"
)
exit /b

:find_session
set "TARGET_SESSION="
for /f "skip=1 tokens=1,3" %%A in ('query user 2^>nul') do (
  if /i "%%A"=="%~1" set "TARGET_SESSION=%%B"
)
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
echo [CMD] %CMD%>>"%MASTER_LOG%"
cmd /c %CMD% >>"%LOG%" 2>&1
cmd /c %CMD% >>"%MASTER_LOG%" 2>&1
echo [RC ] !errorlevel!>>"%LOG%"
echo [RC ] !errorlevel!>>"%MASTER_LOG%"
if not "!errorlevel!"=="0" set "HAS_ERROR=1"
exit /b

:END
echo ===== RESET END %DATE% %TIME% =====>>"%LOG%"
echo ===== RESET END %DATE% %TIME% =====>>"%MASTER_LOG%"
if exist "%ProgramData%\resetovac_tc_elevated.bat" del /q "%ProgramData%\resetovac_tc_elevated.bat" >nul 2>&1
echo Hotovo. Log: %LOG%
echo Stiskni ENTER pro ukonceni.
set /p "_end=> "
exit
