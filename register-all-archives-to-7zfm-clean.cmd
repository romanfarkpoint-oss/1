@echo off
setlocal enableextensions enabledelayedexpansion

REM Ciste znovunastaveni asociaci archivnich pripon na 7zFM.exe pres SetUserFTA
REM Pouziti:
REM   register-all-archives-to-7zfm-clean.cmd "C:\cesta\k\7zFM.exe"

set "SCRIPT_DIR=%~dp0"
set "SETUSERFTA=%SCRIPT_DIR%SetUserFTA.exe"
set "SEVENZIP=%~1"
set "PROGID=7zFM.Archive"

if not exist "%SETUSERFTA%" (
  echo [CHYBA] Nenalezen %SETUSERFTA%
  exit /b 1
)

if "%SEVENZIP%"=="" (
  if exist "%SCRIPT_DIR%7zFM.exe" set "SEVENZIP=%SCRIPT_DIR%7zFM.exe"
)

if "%SEVENZIP%"=="" (
  echo [CHYBA] Zadejte cestu k 7zFM.exe jako prvni argument.
  echo Priklad: register-all-archives-to-7zfm-clean.cmd "C:\Programy\zSkripty\7-Zip\7zFM.exe"
  exit /b 1
)

if not exist "%SEVENZIP%" (
  echo [CHYBA] 7zFM.exe neexistuje: %SEVENZIP%
  exit /b 1
)

echo [INFO] Pouzivam: %SEVENZIP%
echo [INFO] Cistim stare user asociace pro archivni pripony...

set EXTENSIONS=.7z .zip .rar .tar .gz .bz2 .xz .zst .tgz .tbz .tbz2 .txz .tzst .iso .cab .arj .lzh .lha .wim .swm .esd .vhd .vhdx .vdi .dmg .rpm .deb .cpio .apk .xpi .jar .war .ear .msi .msp

for %%E in (%EXTENSIONS%) do (
  reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\%%E\UserChoice" /f >nul 2>nul
  reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\%%E\UserChoiceLatest" /f >nul 2>nul
  reg delete "HKCU\Software\Classes\%%E" /f >nul 2>nul
)

echo [INFO] Zapisuji cisty ProgID a prikaz otevreni...
reg add "HKCU\Software\Classes\%PROGID%" /ve /d "7-Zip Archive" /f >nul
reg add "HKCU\Software\Classes\%PROGID%\DefaultIcon" /ve /d "\"%SEVENZIP%\",0" /f >nul
reg add "HKCU\Software\Classes\%PROGID%\shell\open\command" /ve /d "\"%SEVENZIP%\" \"%%1\"" /f >nul

echo [INFO] Registruji aplikaci 7zFM.exe do OpenWith...
reg add "HKCU\Software\Classes\Applications\7zFM.exe" /v "FriendlyAppName" /d "7-Zip File Manager" /f >nul
reg add "HKCU\Software\Classes\Applications\7zFM.exe\DefaultIcon" /ve /d "\"%SEVENZIP%\",0" /f >nul
reg add "HKCU\Software\Classes\Applications\7zFM.exe\shell\open\command" /ve /d "\"%SEVENZIP%\" \"%%1\"" /f >nul

set /a OK=0
set /a FAIL=0

echo [INFO] Nastavuji vsechny archivni pripony pres SetUserFTA...
for %%E in (%EXTENSIONS%) do (
  reg add "HKCU\Software\Classes\%%E" /ve /d "%PROGID%" /f >nul
  reg add "HKCU\Software\Classes\%%E\OpenWithProgids" /v "%PROGID%" /t REG_NONE /d "" /f >nul
  reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\%%E\OpenWithList" /v "a" /d "7zFM.exe" /f >nul
  reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\%%E\OpenWithProgids" /v "%PROGID%" /t REG_NONE /d "" /f >nul

  "%SETUSERFTA%" %%E %PROGID%
  if errorlevel 1 (
    set /a FAIL+=1
    echo [WARN] %%E - SetUserFTA vratilo chybu
  ) else (
    set /a OK+=1
    echo [OK] %%E
  )
)

echo.
echo [VYSLEDEK] OK: !OK!, CHYBY: !FAIL!
echo [HOTOVO] Pokud jste menil UserChoiceLatest, restartujte Explorer nebo PC.
exit /b 0
