@echo off
setlocal enableextensions enabledelayedexpansion

REM Registrace vsech beznych archivnich pripon na 7zFM.exe pomoci SetUserFTA.exe

set "SCRIPT_DIR=%~dp0"
set "SETUSERFTA=%SCRIPT_DIR%SetUserFTA.exe"

if not exist "%SETUSERFTA%" (
  echo [CHYBA] Nenalezen %SETUSERFTA%
  exit /b 1
)

set "SEVENZIP="
if exist "%ProgramFiles%\7-Zip\7zFM.exe" set "SEVENZIP=%ProgramFiles%\7-Zip\7zFM.exe"
if not defined SEVENZIP if exist "%ProgramFiles(x86)%\7-Zip\7zFM.exe" set "SEVENZIP=%ProgramFiles(x86)%\7-Zip\7zFM.exe"
if not defined SEVENZIP (
  echo [CHYBA] Nenalezen 7zFM.exe v Program Files ani Program Files ^(x86^).
  echo Upravte promennou SEVENZIP ve skriptu rucne.
  exit /b 1
)

set "PROGID=7zFM.Archive"

echo [INFO] Pouzivam: %SEVENZIP%

echo [INFO] Vytvarim ProgID %PROGID% v HKCU...
reg add "HKCU\Software\Classes\%PROGID%" /ve /d "7-Zip Archive" /f >nul
reg add "HKCU\Software\Classes\%PROGID%\DefaultIcon" /ve /d "\"%SEVENZIP%\",0" /f >nul
reg add "HKCU\Software\Classes\%PROGID%\shell\open\command" /ve /d "\"%SEVENZIP%\" \"%%1\"" /f >nul

set EXTENSIONS=.7z .zip .rar .tar .gz .bz2 .xz .zst .tgz .tbz .tbz2 .txz .tzst .iso .cab .arj .lzh .lha .wim .swm .esd .vhd .vhdx .vdi .dmg .rpm .deb .cpio .apk .xpi .jar .war .ear .msi .msp

for %%E in (%EXTENSIONS%) do (
  echo [INFO] Nastavuji %%E na %PROGID%
  "%SETUSERFTA%" %%E %PROGID% >nul
  if errorlevel 1 (
    echo [WARN] Nepodarilo se nastavit %%E
  )
)

echo.
echo [HOTOVO] Archivni pripony byly namapovany na 7zFM.exe.
echo Projevi se pri dvojkliku v Pruzkumniku/na plose pro aktualniho uzivatele.
exit /b 0
