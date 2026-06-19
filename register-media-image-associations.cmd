@echo off
setlocal enableextensions enabledelayedexpansion

REM Registrace media a obrazovych pripon pro aktualniho uzivatele pres SetUserFTA.
REM SetUserFTA musi byt po vypnuti UserChoiceLatest spusten pro kazdeho uzivatele zvlast.

set "SETUSERFTA=D:\SetUserFTA.exe"
set "MEDIA_AHK=P:\Programy\zSkripty\AHK\Media - Playlist.ahk"
set "IRFANVIEW=P:\Programy\IrfanView\i_view64.exe"

set "VLC_PROGID=Roman.MediaPlaylist.VLC"
set "WINAMP_PROGID=Roman.MediaPlaylist.Winamp"
set "IRFAN_PROGID=Roman.IrfanView.Image"

if not exist "%SETUSERFTA%" (
  echo [CHYBA] Nenalezen %SETUSERFTA%
  exit /b 1
)

call :FindAutoHotkey
if not defined AHK_EXE (
  echo [CHYBA] Nenalezen AutoHotkey v2 executable.
  echo        Nainstalujte AutoHotkey nebo upravte promennou AHK_EXE ve skriptu.
  exit /b 1
)

if not exist "%MEDIA_AHK%" (
  echo [CHYBA] Nenalezen media skript: %MEDIA_AHK%
  exit /b 1
)

:MENU
echo.
echo Vyber asociace, ktere se maji nastavit pro aktualniho uzivatele:
echo   1^) IrfanView + Winamp + VLC
echo   2^) IrfanView
echo   3^) Winamp + VLC
echo.
choice /c 123 /n /m "Volba [1-3]: "
set "CHOICE_CODE=%ERRORLEVEL%"
echo.

set "OK_COUNT=0"
set "WARN_COUNT=0"

if "%CHOICE_CODE%"=="1" (
  call :RegisterMedia
  call :RegisterImages
) else if "%CHOICE_CODE%"=="2" (
  call :RegisterImages
) else if "%CHOICE_CODE%"=="3" (
  call :RegisterMedia
) else (
  echo [CHYBA] Neplatna volba.
  exit /b 1
)

echo.
echo [HOTOVO] SetUserFTA uspesne: !OK_COUNT!, varovani: !WARN_COUNT!
echo [POZN] Pokud se zmena hned neprojevi, restartujte Explorer nebo se odhlaste/prihlaste.
exit /b 0

:FindAutoHotkey
set "AHK_EXE="
if exist "P:\Programy\AutoHotkey\v2\AutoHotkey64.exe" set "AHK_EXE=P:\Programy\AutoHotkey\v2\AutoHotkey64.exe"
if not defined AHK_EXE if exist "%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe" set "AHK_EXE=%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe"
if not defined AHK_EXE if exist "%ProgramFiles%\AutoHotkey\AutoHotkey64.exe" set "AHK_EXE=%ProgramFiles%\AutoHotkey\AutoHotkey64.exe"
if not defined AHK_EXE if exist "%ProgramFiles(x86)%\AutoHotkey\AutoHotkey64.exe" set "AHK_EXE=%ProgramFiles(x86)%\AutoHotkey\AutoHotkey64.exe"
exit /b 0

:RegisterProgIds
echo [INFO] Vytvarim ProgID v HKCU...
reg add "HKCU\Software\Classes\%VLC_PROGID%" /ve /d "Media Playlist - VLC" /f >nul
reg add "HKCU\Software\Classes\%VLC_PROGID%\shell\open\command" /ve /d "\"%AHK_EXE%\" \"%MEDIA_AHK%\" --vlc \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\%WINAMP_PROGID%" /ve /d "Media Playlist - Winamp" /f >nul
reg add "HKCU\Software\Classes\%WINAMP_PROGID%\shell\open\command" /ve /d "\"%AHK_EXE%\" \"%MEDIA_AHK%\" --winamp \"%%1\"" /f >nul
exit /b 0

:RegisterIrfanProgId
if not exist "%IRFANVIEW%" (
  echo [CHYBA] Nenalezen IrfanView: %IRFANVIEW%
  exit /b 1
)
reg add "HKCU\Software\Classes\%IRFAN_PROGID%" /ve /d "IrfanView Image" /f >nul
reg add "HKCU\Software\Classes\%IRFAN_PROGID%\DefaultIcon" /ve /d "\"%IRFANVIEW%\",0" /f >nul
reg add "HKCU\Software\Classes\%IRFAN_PROGID%\shell\open\command" /ve /d "\"%IRFANVIEW%\" \"%%1\"" /f >nul
exit /b 0

:RegisterMedia
call :RegisterProgIds
set EXTENSIONS=.264 .265 .3g2 .3gp .3gp2 .3gpp .amv .asf .avi .av1 .avc .avs .bik .braw .bsf .camrec .cine .dash .dav .divx .drc .dv .dvr-ms .evo .f4p .f4v .flc .fli .flv .g64 .gvi .gxf .h261 .h263 .h264 .h265 .hevc .ifo .imx .ismv .ivf .m1v .m2p .m2t .m2ts .m2v .m4e .m4v .mj2 .mjpeg .mjpg .mks .mkv .mng .mov .movie .mp2v .mp4 .mp4v .mpe .mpeg .mpeg1 .mpeg2 .mpeg4 .mpg .mpg2 .mpv .mpv2 .mts .mve .mxf .mxg .nsv .nut .nuv .ogm .ogv .ogx .pss .qt .r3d .rec .rm .rmvb .roq .rv .sfd .smk .ssif .swf .tod .tp .trp .ts .tts .vfw .vid .vob .vro .webm .wm .wmv .wtv .xesc .xvid .y4m .2sf .3ga .4mp .669 .8svx .aa .aax .act .adpcm .afc .alac .amr .ape .apl .awb .caf .cdda .dff .dsf .dsm .dts .dtshd .dvf .f32 .f64 .fla .flac .gsm .hcom .iff .it .kar .la .m3u .m3u8 .m4p .m4r .mid .midi .mka .mlp .mmf .mo3 .mod .mpc .mpp .msv .oga .oma .opus .qcp .ra .ram .rmi .s3m .sds .shn .snd .spc .spx .tak .tta .voc .vox .vqf .w64 .wax .wma .wv .wve .xa .xm
for %%E in (%EXTENSIONS%) do call :SetOne %%E %VLC_PROGID%
set EXTENSIONS=.aac .ac3 .adt .adts .aif .aifc .aiff .au .cda .m4a .m4b .mp1 .mp2 .mp3 .mpa .ogg .pls .wav .wave
for %%E in (%EXTENSIONS%) do call :SetOne %%E %WINAMP_PROGID%
exit /b 0

:RegisterImages
call :RegisterIrfanProgId || exit /b 1
set EXTENSIONS=.3fr .ai .ani .apng .arw .avif .bay .bmp .bmq .cal .cin .clip .cpt .cr2 .cr3 .crw .cur .dc2 .dcr .dcx .dds .dib .dng .dpx .emf .eps .erf .exif .exr .fff .fits .flif .fpx .gif .hdr .heic .heif .icb .icns .ico .iiq .j2c .j2k .jas .jb2 .jbig .jbig2 .jfi .jfif .jif .jng .jp2 .jpc .jpe .jpeg .jpf .jpg .jpm .jps .jpx .jxl .k25 .kdc .lbm .mef .miff .mos .mrw .nef .nrw .ora .orf .pam .pbm .pcd .pcx .pef .pfm .pgm .pic .pict .png .pnm .ppm .psb .psd .psp .pspimage .ptx .pxn .qoi .raf .ras .raw .rgb .rgba .rle .rw2 .rwl .sgi .sr2 .srf .srw .svg .svgz .tga .tif .tiff .vda .vst .wbmp .webp .wmf .x3f .xbm .xcf .xpm
for %%E in (%EXTENSIONS%) do call :SetOne %%E %IRFAN_PROGID%
exit /b 0

:SetOne
set "EXT=%~1"
set "PROGID=%~2"
echo [INFO] Nastavuji %EXT% -^> %PROGID%
reg add "HKCU\Software\Classes\%EXT%" /ve /d "%PROGID%" /f >nul
reg add "HKCU\Software\Classes\%EXT%\OpenWithProgids" /v "%PROGID%" /t REG_NONE /d "" /f >nul
"%SETUSERFTA%" %EXT% %PROGID%
if errorlevel 1 (
  echo [WARN] SetUserFTA selhalo pro %EXT%.
  set /a WARN_COUNT+=1
) else (
  set /a OK_COUNT+=1
)
exit /b 0
