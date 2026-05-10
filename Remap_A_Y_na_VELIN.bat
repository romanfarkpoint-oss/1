@echo off
setlocal

echo [1/5] Uvolnuji pismena A: a Y: (net use + subst)...
call :FreeLetter A:
call :FreeLetter Y:

echo [2/5] Kontrola, ze pismena jsou volna...
call :EnsureFree A: || exit /b 1
call :EnsureFree Y: || exit /b 1

echo [3/5] Mapuji A: na \\VELIN\Users\R\A ...
net use A: \\VELIN\Users\R\A /persistent:yes
if errorlevel 1 (
  echo CHYBA: Nepodarilo se namapovat A:
  exit /b 1
)

echo [4/5] Mapuji Y: na \\VELIN\Downloads ...
net use Y: \\VELIN\Downloads /persistent:yes
if errorlevel 1 (
  echo CHYBA: Nepodarilo se namapovat Y:
  exit /b 1
)

echo [5/5] Hotovo. Aktualni mapovani:
net use A:
net use Y:

echo.
echo OK: A: = \\VELIN\Users\R\A
echo OK: Y: = \\VELIN\Downloads
endlocal
exit /b 0

:FreeLetter
set "L=%~1"
net use %L% /delete /y >nul 2>&1
subst %L% /d >nul 2>&1
exit /b 0

:EnsureFree
set "L=%~1"
if exist %L%\NUL (
  echo CHYBA: %L% je stale obsazene. Zavri okna/pruzkumnika na %L% a spust skript znovu.
  exit /b 1
)
exit /b 0
