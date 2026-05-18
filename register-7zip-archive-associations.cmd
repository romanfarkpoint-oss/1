@echo off
setlocal enableextensions enabledelayedexpansion

REM Registrace vsech beznych archivnich pripon na 7zFM.exe pomoci SetUserFTA.exe
REM Funguje i kdyz mate jen soubory 7zFM.exe/7z.exe/7z.dll z drivejsi instalace.

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
echo [INFO] Vytvarim registrace 7zFM a ProgID v HKCU...

REM ProgID + prikaz otevreni
reg add "HKCU\Software\Classes\%PROGID%" /ve /d "7-Zip Archive" /f >nul
reg add "HKCU\Software\Classes\%PROGID%\DefaultIcon" /ve /d "\"%SEVENZIP%\",0" /f >nul
reg add "HKCU\Software\Classes\%PROGID%\shell\open\command" /ve /d "\"%SEVENZIP%\" \"%%1\"" /f >nul

REM Registrace aplikace 7zFM.exe pro OpenWith / shell
reg add "HKCU\Software\Classes\Applications\7zFM.exe" /v "FriendlyAppName" /d "7-Zip File Manager" /f >nul
reg add "HKCU\Software\Classes\Applications\7zFM.exe\DefaultIcon" /ve /d "\"%SEVENZIP%\",0" /f >nul
reg add "HKCU\Software\Classes\Applications\7zFM.exe\shell\open\command" /ve /d "\"%SEVENZIP%\" \"%%1\"" /f >nul

set EXTENSIONS=.7z .zip .rar .tar .gz .bz2 .xz .zst .tgz .tbz .tbz2 .txz .tzst .iso .cab .arj .lzh .lha .wim .swm .esd .vhd .vhdx .vdi .dmg .rpm .deb .cpio .apk .xpi .jar .war .ear .msi .msp

for %%E in (%EXTENSIONS%) do (
  echo [INFO] Nastavuji %%E na %PROGID%

  REM Fallback registrace pripony
  reg add "HKCU\Software\Classes\%%E" /ve /d "%PROGID%" /f >nul
  reg add "HKCU\Software\Classes\%%E\OpenWithProgids" /v "%PROGID%" /t REG_NONE /d "" /f >nul

  REM OpenWithList pomaha, kdyz je 7zFM mimo standardni instalaci
  reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\%%E\OpenWithList" /v "a" /d "7zFM.exe" /f >nul
  reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\%%E\OpenWithProgids" /v "%PROGID%" /t REG_NONE /d "" /f >nul

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

echo [HOTOVO] Archivni pripony byly namapovany na 7zFM.exe pro aktualniho uzivatele.
exit /b 0
