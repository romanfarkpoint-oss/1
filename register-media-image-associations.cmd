@echo off
setlocal enableextensions enabledelayedexpansion

REM Registrace media a obrazovych pripon pro aktualniho uzivatele pres SetUserFTA.
REM SetUserFTA musi byt po vypnuti UserChoiceLatest spusten pro kazdeho uzivatele zvlast.
REM Dulezite: SetUserFTA Personal Edition potrebuje WMIC. Kontrolujeme ho predem,
REM aby SetUserFTA nevypisoval stejne varovani znovu pro kazdou priponu.

set "SETUSERFTA=D:\SetUserFTA.exe"
set "MEDIA_AHK=P:\Programy\zSkripty\AHK\Media - Playlist.ahk"
set "IRFANVIEW=P:\Programy\IrfanView\i_view64.exe"

set "VLC_PROGID=Roman.MediaPlaylist.VLC"
set "WINAMP_PROGID=Roman.MediaPlaylist.Winamp"
set "IRFAN_PROGID=Roman.IrfanView.Image"

set "LOG_DIR=C:\logy"
set "LOG_FILE=%LOG_DIR%\fta.txt"
set "SETUSERFTA_EXIT=0"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>nul
>>"%LOG_FILE%" echo.
>>"%LOG_FILE%" echo ============================================================
>>"%LOG_FILE%" echo START %DATE% %TIME% register-media-image-associations.cmd
>>"%LOG_FILE%" echo SETUSERFTA=%SETUSERFTA%
>>"%LOG_FILE%" echo MEDIA_AHK=%MEDIA_AHK%
>>"%LOG_FILE%" echo IRFANVIEW=%IRFANVIEW%
call :Log "Log soubor: %LOG_FILE%"

if not exist "%SETUSERFTA%" (
  call :Log "[CHYBA] Nenalezen %SETUSERFTA%"
  call :WaitBeforeExit
  exit /b 1
)

call :EnsureWmic
if errorlevel 1 exit /b 1
call :Log "WMIC kontrola OK."

call :FindAutoHotkey
if not defined AHK_EXE (
  call :Log "[CHYBA] Nenalezen AutoHotkey v2 executable."
  echo        Nainstalujte AutoHotkey nebo upravte promennou AHK_EXE ve skriptu.
  >>"%LOG_FILE%" echo        Nainstalujte AutoHotkey nebo upravte promennou AHK_EXE ve skriptu.
  call :WaitBeforeExit
  exit /b 1
)
call :Log "AutoHotkey nalezen: %AHK_EXE%"

if not exist "%MEDIA_AHK%" (
  call :Log "[CHYBA] Nenalezen media skript: %MEDIA_AHK%"
  call :WaitBeforeExit
  exit /b 1
)
call :Log "Media skript nalezen."

:MENU
echo.
echo Vyber asociace, ktere se maji nastavit pro aktualniho uzivatele:
echo   1^) IrfanView + Winamp + VLC
echo   2^) IrfanView
echo   3^) Winamp + VLC
echo.
choice /c 123 /n /m "Volba [1-3]: "
set "CHOICE_CODE=%ERRORLEVEL%"
call :Log "Zvolena moznost: %CHOICE_CODE%"
echo.

set "OK_COUNT=0"
set "WARN_COUNT=0"
set "EXT_COUNT=0"
set "CONFIG_FILE=%TEMP%\SetUserFTA_media_image_%RANDOM%%RANDOM%.txt"
set "AUTO_CONFIRM_STOP=%TEMP%\SetUserFTA_auto_confirm_%RANDOM%%RANDOM%.stop"
set "AUTO_CONFIRM_PS1=%TEMP%\SetUserFTA_auto_confirm_%RANDOM%%RANDOM%.ps1"

call :Log "Docasny konfiguracni soubor: %CONFIG_FILE%"
type nul > "%CONFIG_FILE%"
if errorlevel 1 (
  call :Log "[CHYBA] Nelze vytvorit docasny konfiguracni soubor: %CONFIG_FILE%"
  call :WaitBeforeExit
  exit /b 1
)

if "%CHOICE_CODE%"=="1" (
  call :Log "[INFO] Volba 1: spoustim RegisterMedia."
  call :RegisterMedia
  if errorlevel 1 goto FAIL
  call :Log "[INFO] Volba 1: RegisterMedia hotovo, spoustim RegisterImages."
  call :RegisterImages
  if errorlevel 1 goto FAIL
) else if "%CHOICE_CODE%"=="2" (
  call :Log "[INFO] Volba 2: spoustim RegisterImages."
  call :RegisterImages
  if errorlevel 1 goto FAIL
) else if "%CHOICE_CODE%"=="3" (
  call :Log "[INFO] Volba 3: spoustim RegisterMedia."
  call :RegisterMedia
  if errorlevel 1 goto FAIL
) else (
  echo [CHYBA] Neplatna volba.
  goto FAIL
)

if "%EXT_COUNT%"=="0" (
  call :Log "[CHYBA] Nebyla pripravena zadna asociace."
  call :CleanupTempFiles
  call :WaitBeforeExit
  exit /b 1
)

echo.
call :Log "[INFO] Spoustim SetUserFTA postupne pro kazdou asociaci z konfiguracniho souboru: %CONFIG_FILE%"
set "OK_COUNT=0"
set "WARN_COUNT=0"
call :ApplyQueuedAssociations
set "SETUSERFTA_EXIT=%ERRORLEVEL%"
if not defined SETUSERFTA_EXIT (
  call :Log "[CHYBA] Interni chyba: SETUSERFTA_EXIT neni nastaven."
  goto FAIL
)
call :Log "SetUserFTA souhrn: OK=!OK_COUNT!, chyby=!WARN_COUNT!, exit=%SETUSERFTA_EXIT%"
call :VerifySampleAssociations
if not "%SETUSERFTA_EXIT%"=="0" (
  call :Log "[CHYBA] Nektere asociace se nepodarilo nastavit."
  call :Log "[POZN] HKCU fallback zaznamy byly vytvoreny, ale Windows UserChoice se nemusel zmenit."
  call :CleanupTempFiles
  call :WaitBeforeExit
  exit /b 1
)

call :CleanupTempFiles

echo.
call :Log "[HOTOVO] Pripraveno asociaci: !EXT_COUNT!, SetUserFTA uspesne: !OK_COUNT!, varovani: !WARN_COUNT!"
call :Log "[POZN] Pokud se zmena hned neprojevi, restartujte Explorer nebo se odhlaste/prihlaste."
call :WaitBeforeExit
exit /b 0

:FAIL
call :Log "[CHYBA] Skript skoncil pres FAIL vetvu."
call :StopSetUserFtaAutoConfirm
call :CleanupTempFiles
call :WaitBeforeExit
exit /b 1

:Log
echo %~1
>>"%LOG_FILE%" echo [%DATE% %TIME%] %~1
exit /b 0

:WaitBeforeExit
echo.
echo Stisknete libovolnou klavesu pro zavreni okna...
pause >nul
exit /b 0

:ApplyQueuedAssociations
set "APPLY_COUNT=0"
for /f "usebackq tokens=1,2 delims=," %%A in ("%CONFIG_FILE%") do (
  set "APPLY_EXT=%%~A"
  set "APPLY_PROGID=%%~B"
  if "!APPLY_PROGID:~0,1!"==" " set "APPLY_PROGID=!APPLY_PROGID:~1!"
  call :ApplyOneAssociation "!APPLY_EXT!" "!APPLY_PROGID!"
  if errorlevel 1 (
    set /a WARN_COUNT+=1
  ) else (
    set /a OK_COUNT+=1
  )
  set /a APPLY_COUNT+=1
  set /a APPLY_MOD=APPLY_COUNT %% 25
  if "!APPLY_MOD!"=="0" call :Log "[INFO] SetUserFTA progress: !APPLY_COUNT!/!EXT_COUNT!"
)
if "%WARN_COUNT%"=="0" exit /b 0
exit /b 1

:ApplyOneAssociation
set "ONE_EXT=%~1"
set "ONE_PROGID=%~2"
>>"%LOG_FILE%" echo [%DATE% %TIME%] SetUserFTA %ONE_EXT% %ONE_PROGID%
start "SetUserFTA %ONE_EXT%" /wait "%SETUSERFTA%" %ONE_EXT% %ONE_PROGID% >>"%LOG_FILE%" 2>&1
set "ONE_EXIT=%ERRORLEVEL%"
if not "%ONE_EXIT%"=="0" >>"%LOG_FILE%" echo [%DATE% %TIME%] WARN SetUserFTA failed: %ONE_EXT% %ONE_PROGID% exit=%ONE_EXIT%
exit /b %ONE_EXIT%

:VerifySampleAssociations
call :Log "[INFO] Overuji ukazkove asociace pres SetUserFTA query."
for %%E in (.mp3 .mp4 .jpg .png) do (
  >>"%LOG_FILE%" echo ----- query %%E start -----
  "%SETUSERFTA%" query %%E >>"%LOG_FILE%" 2>&1
  >>"%LOG_FILE%" echo ----- query %%E end -----
)
exit /b 0

:StartSetUserFtaAutoConfirm
REM Vypnuto: dlouho bezici PowerShell watcher mohl zustat aktivni po chybe
REM a potvrzovat dalsi okna. SetUserFTA se ted spousti pres start /wait,
REM takze batch ceka na kazdou instanci a nepusti jich stovky najednou.
call :Log "Auto-confirm watcher je vypnuty; SetUserFTA bezi synchronne pres start /wait."
exit /b 0

:StopSetUserFtaAutoConfirm
exit /b 0

:CleanupTempFiles
>>"%LOG_FILE%" echo [%DATE% %TIME%] Cleanup temp files.
del "%CONFIG_FILE%" >nul 2>nul
del "%AUTO_CONFIRM_STOP%" >nul 2>nul
del "%AUTO_CONFIRM_PS1%" >nul 2>nul
exit /b 0

:EnsureWmic
where wmic.exe >nul 2>nul
if not errorlevel 1 exit /b 0
if exist "%SystemRoot%\System32\wbem\wmic.exe" exit /b 0

call :Log "[CHYBA] WMIC neni v tomto Windows nainstalovany nebo neni v PATH."
echo.
call :Log "SetUserFTA Personal Edition bez WMIC vypisuje opakovane varovani a asociace nenastavi spolehlive."
call :Log "Nejspis staci otevrit PowerShell jako spravce a spustit:"
echo.
call :Log "  add-WindowsCapability -online -name WMIC"
echo.
call :Log "Potom restartujte Windows a spustte tento skript znovu."
call :WaitBeforeExit
exit /b 1

:FindAutoHotkey
set "AHK_EXE="
if exist "P:\Programy\AutoHotkey\v2\AutoHotkey64.exe" set "AHK_EXE=P:\Programy\AutoHotkey\v2\AutoHotkey64.exe"
if not defined AHK_EXE if exist "%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe" set "AHK_EXE=%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe"
if not defined AHK_EXE if exist "%ProgramFiles%\AutoHotkey\AutoHotkey64.exe" set "AHK_EXE=%ProgramFiles%\AutoHotkey\AutoHotkey64.exe"
if not defined AHK_EXE if exist "%ProgramFiles(x86)%\AutoHotkey\AutoHotkey64.exe" set "AHK_EXE=%ProgramFiles(x86)%\AutoHotkey\AutoHotkey64.exe"
exit /b 0

:RegisterProgIds
call :Log "[INFO] Vytvarim ProgID v HKCU..."
reg add "HKCU\Software\Classes\%VLC_PROGID%" /ve /d "Media Playlist - VLC" /f >nul
reg add "HKCU\Software\Classes\%VLC_PROGID%\shell\open\command" /ve /d "\"%AHK_EXE%\" \"%MEDIA_AHK%\" --vlc \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\%WINAMP_PROGID%" /ve /d "Media Playlist - Winamp" /f >nul
reg add "HKCU\Software\Classes\%WINAMP_PROGID%\shell\open\command" /ve /d "\"%AHK_EXE%\" \"%MEDIA_AHK%\" --winamp \"%%1\"" /f >nul
exit /b 0

:RegisterIrfanProgId
if not exist "%IRFANVIEW%" (
  call :Log "[CHYBA] Nenalezen IrfanView: %IRFANVIEW%"
  exit /b 1
)
call :Log "IrfanView nalezen: %IRFANVIEW%"
reg add "HKCU\Software\Classes\%IRFAN_PROGID%" /ve /d "IrfanView Image" /f >nul
reg add "HKCU\Software\Classes\%IRFAN_PROGID%\DefaultIcon" /ve /d "\"%IRFANVIEW%\",0" /f >nul
reg add "HKCU\Software\Classes\%IRFAN_PROGID%\shell\open\command" /ve /d "\"%IRFANVIEW%\" \"%%1\"" /f >nul
exit /b 0

:RegisterMedia
call :Log "[INFO] RegisterMedia start."
call :RegisterProgIds
for %%E in (.264 .265 .3g2 .3gp .3gp2 .3gpp .amv .asf .avi .av1 .avc .avs .bik .braw .bsf .camrec .cine .dash .dav .divx .drc .dv .dvr-ms .evo .f4p .f4v .flc .fli .flv .g64 .gvi .gxf .h261 .h263 .h264) do call :QueueOne %%E %VLC_PROGID%
for %%E in (.h265 .hevc .ifo .imx .ismv .ivf .m1v .m2p .m2t .m2ts .m2v .m4e .m4v .mj2 .mjpeg .mjpg .mks .mkv .mng .mov .movie .mp2v .mp4 .mp4v .mpe .mpeg .mpeg1 .mpeg2 .mpeg4 .mpg .mpg2 .mpv .mpv2 .mts .mve) do call :QueueOne %%E %VLC_PROGID%
for %%E in (.mxf .mxg .nsv .nut .nuv .ogm .ogv .ogx .pss .qt .r3d .rec .rm .rmvb .roq .rv .sfd .smk .ssif .swf .tod .tp .trp .ts .tts .vfw .vid .vob .vro .webm .wm .wmv .wtv .xesc .xvid) do call :QueueOne %%E %VLC_PROGID%
for %%E in (.y4m .2sf .3ga .4mp .669 .8svx .aa .aax .act .adpcm .afc .alac .amr .ape .apl .awb .caf .cdda .dff .dsf .dsm .dts .dtshd .dvf .f32 .f64 .fla .flac .gsm .hcom .iff .it .kar .la .m3u) do call :QueueOne %%E %VLC_PROGID%
for %%E in (.m3u8 .m4p .m4r .mid .midi .mka .mlp .mmf .mo3 .mod .mpc .mpp .msv .oga .oma .opus .qcp .ra .ram .rmi .s3m .sds .shn .snd .spc .spx .tak .tta .voc .vox .vqf .w64 .wax .wma .wv) do call :QueueOne %%E %VLC_PROGID%
for %%E in (.wve .xa .xm) do call :QueueOne %%E %VLC_PROGID%
for %%E in (.aac .ac3 .adt .adts .aif .aifc .aiff .au .cda .m4a .m4b .mp1 .mp2 .mp3 .mpa .ogg .pls .wav .wave) do call :QueueOne %%E %WINAMP_PROGID%
call :Log "[INFO] Media asociace pripraveny. Celkem zatim: !EXT_COUNT!"
exit /b 0

:RegisterImages
call :Log "[INFO] RegisterImages start."
call :RegisterIrfanProgId
if errorlevel 1 (
  call :Log "[CHYBA] RegisterIrfanProgId selhalo."
  exit /b 1
)
call :Log "[INFO] RegisterIrfanProgId hotovo, frontuji obrazove pripony."
for %%E in (.3fr .ai .ani .apng .arw .avif .bay .bmp .bmq .cal .cin .clip .cpt .cr2 .cr3 .crw .cur .dc2 .dcr .dcx .dds .dib .dng .dpx .emf .eps .erf .exif .exr .fff .fits .flif .fpx .gif .hdr) do call :QueueOne %%E %IRFAN_PROGID%
for %%E in (.heic .heif .icb .icns .ico .iiq .j2c .j2k .jas .jb2 .jbig .jbig2 .jfi .jfif .jif .jng .jp2 .jpc .jpe .jpeg .jpf .jpg .jpm .jps .jpx .jxl .k25 .kdc .lbm .mef .miff .mos .mrw .nef .nrw) do call :QueueOne %%E %IRFAN_PROGID%
for %%E in (.ora .orf .pam .pbm .pcd .pcx .pef .pfm .pgm .pic .pict .png .pnm .ppm .psb .psd .psp .pspimage .ptx .pxn .qoi .raf .ras .raw .rgb .rgba .rle .rw2 .rwl .sgi .sr2 .srf .srw .svg .svgz) do call :QueueOne %%E %IRFAN_PROGID%
for %%E in (.tga .tif .tiff .vda .vst .wbmp .webp .wmf .x3f .xbm .xcf .xpm) do call :QueueOne %%E %IRFAN_PROGID%
call :Log "[INFO] Obrazove asociace pripraveny. Celkem zatim: !EXT_COUNT!"
exit /b 0

:QueueOne
set "EXT=%~1"
set "PROGID=%~2"
REM Tichy rezim: nevypisujeme kazdou priponu zvlast, jen souhrn na konci.
reg add "HKCU\Software\Classes\%EXT%" /ve /d "%PROGID%" /f >nul
reg add "HKCU\Software\Classes\%EXT%\OpenWithProgids" /v "%PROGID%" /t REG_NONE /d "" /f >nul
>>"%CONFIG_FILE%" echo %EXT%, %PROGID%
set /a EXT_COUNT+=1
exit /b 0
