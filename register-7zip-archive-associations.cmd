@echo off
setlocal enableextensions enabledelayedexpansion

REM Registrace vsech beznych archivnich pripon na 7zFM.exe pomoci SetUserFTA.exe
REM Podporuje:
REM  1) cesta predana jako 1. argument skriptu
REM  2) 7zFM.exe vedle tohoto skriptu
REM  3) standardni umisteni v Program Files

set "SCRIPT_DIR=%~dp0"
set "SETUSERFTA=%SCRIPT_DIR%SetUserFTA.exe"

if not exist "%SETUSERFTA%" (
  echo [CHYBA] Nenalezen %SETUSERFTA%
  exit /b 1
)

set "SEVENZIP="

REM 1) cesta jako argument
if not "%~1"=="" set "SEVENZIP=%~1"

REM 2) 7zFM.exe vedle skriptu
if not defined SEVENZIP if exist "%SCRIPT_DIR%7zFM.exe" set "SEVENZIP=%SCRIPT_DIR%7zFM.exe"

REM 3) standardni cesty instalace
if not defined SEVENZIP if exist "%ProgramFiles%\7-Zip\7zFM.exe" set "SEVENZIP=%ProgramFiles%\7-Zip\7zFM.exe"
if not defined SEVENZIP if exist "%ProgramFiles(x86)%\7-Zip\7zFM.exe" set "SEVENZIP=%ProgramFiles(x86)%\7-Zip\7zFM.exe"

if not defined SEVENZIP (
  echo [CHYBA] Nenalezen 7zFM.exe.
  echo.
  echo Moznosti:
  echo   1^) Dejte 7zFM.exe vedle tohoto skriptu
  echo   2^) Spustte skript s cestou k 7zFM.exe, napr.:
  echo      register-7zip-archive-associations.cmd "D:\Tools\7zip\7zFM.exe"
  echo   3^) Nainstalujte 7-Zip do Program Files
  exit /b 1
)

if not exist "%SEVENZIP%" (
  echo [CHYBA] Zadana cesta k 7zFM.exe neexistuje:
  echo %SEVENZIP%
  exit /b 1
)

set "PROGID=7zFM.Archive"
set "OK_COUNT=0"
set "WARN_COUNT=0"

echo [INFO] Pouzivam: %SEVENZIP%
echo [INFO] Vytvarim ProgID %PROGID% v HKCU...

reg add "HKCU\Software\Classes\%PROGID%" /ve /d "7-Zip Archive" /f >nul
reg add "HKCU\Software\Classes\%PROGID%\DefaultIcon" /ve /d "\"%SEVENZIP%\",0" /f >nul
reg add "HKCU\Software\Classes\%PROGID%\shell\open\command" /ve /d "\"%SEVENZIP%\" \"%%1\"" /f >nul

set EXTENSIONS=.7z .zip .rar .tar .gz .bz2 .xz .zst .tgz .tbz .tbz2 .txz .tzst .iso .cab .arj .lzh .lha .wim .swm .esd .vhd .vhdx .vdi .dmg .rpm .deb .cpio .apk .xpi .jar .war .ear .msi .msp

for %%E in (%EXTENSIONS%) do (
  echo [INFO] Nastavuji %%E na %PROGID%

  REM Fallback registrace v HKCU\Software\Classes
  reg add "HKCU\Software\Classes\%%E" /ve /d "%PROGID%" /f >nul
  reg add "HKCU\Software\Classes\%%E\OpenWithProgids" /v "%PROGID%" /t REG_NONE /d "" /f >nul

  "%SETUSERFTA%" %%E %PROGID%
  if errorlevel 1 (
    echo [WARN] SetUserFTA selhalo pro %%E - fallback v HKCU je i tak nastaven.
    set /a WARN_COUNT+=1
  ) else (
    set /a OK_COUNT+=1
  )
)

echo.
echo [INFO] Uspesne pres SetUserFTA: !OK_COUNT!, varovani: !WARN_COUNT!
if not "!WARN_COUNT!"=="0" (
  echo [POZN] Pokud dvojklik stale nefunguje, restartujte Explorer nebo se odhlaste/prihlaste.
)

echo [HOTOVO] Archivni pripony byly namapovany na 7zFM.exe.
echo Projevi se pri dvojkliku v Pruzkumniku/na plose pro aktualniho uzivatele.
exit /b 0
