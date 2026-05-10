@echo off
setlocal

echo [1/4] Rusim puvodni mapovani A: a Y: (pokud existuje)...
net use A: /delete /y >nul 2>&1
net use Y: /delete /y >nul 2>&1

echo [2/4] Mapuji A: na \\VELIN\Users\R\A ...
net use A: \\VELIN\Users\R\A /persistent:yes
if errorlevel 1 (
  echo CHYBA: Nepodarilo se namapovat A:
  exit /b 1
)

echo [3/4] Mapuji Y: na \\VELIN\Downloads ...
net use Y: \\VELIN\Downloads /persistent:yes
if errorlevel 1 (
  echo CHYBA: Nepodarilo se namapovat Y:
  exit /b 1
)

echo [4/4] Hotovo. Aktualni mapovani:
net use A:
net use Y:

echo.
echo OK: A: = \\VELIN\Users\R\A
echo OK: Y: = \\VELIN\Downloads
endlocal
