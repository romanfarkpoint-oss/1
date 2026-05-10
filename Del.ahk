#Requires AutoHotkey v2.0
#SingleInstance Off ; musi zustat Off kvuli jednorazovemu spousteni z Total Commanderu pres /tcbutton
#MaxThreadsPerHotkey 1
Persistent
SendMode "Event"
DetectHiddenWindows True
SetTitleMatchMode 2
SetKeyDelay 30, 30

; ============================================================
; HOMESCAPES KONTROLA HLASITOSTI
; ============================================================

SetTimer(CheckHomescapes, 5000)

CheckHomescapes() {
    HomescapesPID := ProcessExist("Homescapes.exe")

    if (HomescapesPID) {
        RunWait "P:\Programy\zSkripty\Ostatni\nircmd.exe setappvolume Homescapes.exe 0.24"
    }
}

; ============================================================
; RUCNI PREMAPOVANI SITOVYCH DISKU NA LOKALNI SLOZKY
; ============================================================
;
; Pokud je mapovany disk ve skutecnosti lokalni slozka, muzes ho sem
; zapsat rucne. Skript se nejdrive pokusi zjistit mapovani automaticky.
; Pokud to nepujde, pouzije tuto tabulku.
;
; Priklad:
; LOCAL_MAPPED_DRIVE_OVERRIDES["Z:"] := "E:\Sdilene"
;
; ============================================================

LOCAL_MAPPED_DRIVE_OVERRIDES := Map()
; A: a Y: ponechány jako síťové cesty (UNC), aby se nepřemapovávaly na lokální disky.
LOCAL_MAPPED_DRIVE_OVERRIDES["A:"] := "\\VELIN\Users\R\A"
LOCAL_MAPPED_DRIVE_OVERRIDES["Y:"] := "\\VELIN\Downloads"

; ============================================================
; DEL PRO TOTAL COMMANDER - VARIANTA A
; ============================================================
;
; DULEZITE:
; Tento skript uz NECHYTA fyzickou klavesu Delete pomoci AHK hotkey.
; Klavesu Delete v Total Commanderu namapuj primo v TC na em_ahk_delete.
;
; usercmd.ini:
;
; [em_ahk_delete]
; cmd=P:\Programy\AutoHotkey\v2\AutoHotkey64.exe
; param="P:\Programy\zSkripty\AHK\Já\Del.ahk" /tcbutton %UL
; menu=AHK Delete
;
; Stejne parametry pouzij i pro rychle tlacitko v TC:
;
; Prikaz:
; P:\Programy\AutoHotkey\v2\AutoHotkey64.exe
;
; Parametry:
; "P:\Programy\zSkripty\AHK\Já\Del.ahk" /tcbutton %UL
;
; CHOVANI:
;
; - hlavni trvala instance Del.ahk BEZI:
;     E: = smazat trvale bez Kose
;     vse ostatni = normalni mazani Total Commanderu
;
; - hlavni trvala instance Del.ahk NEBEZI:
;     vse = normalni mazani Total Commanderu
;
; ZADNY nahradni kos se nepouziva.
; ZADNY FileRecycle se nepouziva.
; ZADNY AHK keyboard hook pro Delete se nepouziva.
;
; ============================================================

APP_TITLE := "AHK_DEL_JAKO_SHIFT_DEL_TC_EXPLORER"
MAIN_MUTEX_NAME := "Local\AHK_DEL_TC_EXPLORER_MAIN_MUTEX"
MAIN_MUTEX_HANDLE := 0
STATE_FILE := A_Temp "\AHK_DEL_JAKO_SHIFT_DEL_TC_EXPLORER.state"
SCRIPT_IS_MAIN_INSTANCE := false
MAIN_STATE_MAX_AGE_SECONDS := 4
DEBUG_DELETE_LOG := true ; prepinac logovani
DEBUG_DELETE_LOG_FILE := "P:\Programy\zSkripty\AHK\Já\Logy\del_tc_delete.log"

; ============================================================
; VLC HTTP ROZHRANI
; ============================================================

VLC_HTTP_HOST := "127.0.0.1"
VLC_HTTP_PORT := "8080"
VLC_HTTP_PASSWORD := "1"

; ============================================================
; VLC OSD CASU NA CELE OBRAZOVCE
; ============================================================

VLC_FULLSCREEN_TIME_OSD := true
; OSD je dole, ale posunute vyse nad titulky, aby neprekryvalo titulky ve VLC.
; Moznosti: "top" nebo "bottom".
; Pro posun jeste vyse zvys VLC_OSD_BOTTOM_MARGIN, pro posun nize ho sniz.
VLC_OSD_POSITION := "bottom"
VLC_OSD_TOP_MARGIN := 80
VLC_OSD_BOTTOM_MARGIN := 270
VLC_OSD_GUI := 0
VLC_OSD_TEXT := 0
VLC_OSD_LAST_TEXT := ""


; ============================================================
; SCHRANKA WINDOWS -> FIREFOX ANONYMNÍ OKNO -> STAZENI
; ============================================================
;
; Funkce převzatá z link.ahk a sloučená do hlavní trvalé instance.
; - hlida schranku Windows
; - kdyz se do schranky dostane http/https odkaz
; - otevre ho ve Firefoxu v anonymnim rezimu pres -private-window
; - potom vrati focus zpet do puvodniho okna
;
; Hotkeys:
; Ctrl + Alt + P = pozastavit / spustit pouze predavani odkazu
; Ctrl + Alt + Q = ukoncit cely hlavni skript
; Ctrl + Alt + V = diagnostika VLC
;
; ============================================================

ClipboardLinkEnabled := true
LastClipboardUrl := ""
LastClipboardUrlTime := 0
FirefoxExePath := "C:\Program Files\Mozilla Firefox\firefox.exe"
ClipboardDuplicateBlockMs := 3000
ClipboardRestoreFocusDelayMs := 500
ClipboardRestoreFocusAttempts := 12
ClipboardRestoreFocusAttemptDelayMs := 150

arg1 := ""
arg2 := ""

if A_Args.Length >= 1 {
    arg1 := StrLower(Trim(A_Args[1]))
}

if A_Args.Length >= 2 {
    arg2 := Trim(A_Args[2])
}

; ============================================================
; TEST TLACITKA TOTAL COMMANDERU
; ============================================================

if (arg1 = "/tctest" || arg1 = "tctest") {
    MsgBox "Tlačítko v Total Commanderu spustilo AHK skript správně.", "AHK test", "Iconi"
    ExitApp
}

; ============================================================
; JEDNORAZOVE VOLANI Z TLACITKA / HOTKEY TOTAL COMMANDERU
; ============================================================

if (arg1 = "/tcbutton" || arg1 = "tcbutton") {
    DebugDeleteLog("tcbutton invoked | arg2=" arg2 " | mainRunning=" (IsMainInstanceEnabled(false) ? "1" : "0"))
    HandleTotalCommanderDeleteButton(arg2)
    ExitApp
}

HandleTotalCommanderDeleteButton(listFileArg) {
    DebugDeleteLog("HandleTotalCommanderDeleteButton start | listFileArg=" listFileArg)
    hwnd := GetTotalCommanderHwnd()

    if !hwnd {
        DebugDeleteLog("TC hwnd not found")
        MsgBox "Skript byl spusten, ale nenasel jsem okno Total Commanderu.", "AHK Delete", "Iconx"
        return
    }

    mainRunning := IsMainInstanceEnabled(false)

    ; Pro rozhodnuti o mazani potrebujeme vyber pres %UL.
    paths := []

    if (Trim(listFileArg) != "") {
        paths := GetPathsFromTcListFile(listFileArg)
    }
    DebugDeleteLog("paths loaded | count=" paths.Length)
    for , p in paths {
        DebugDeleteLog("path=" p)
    }

    if (paths.Length = 0) {
        DebugDeleteLog("no paths parsed from %UL")
        TrayTip "AHK Delete", "Nepodarilo se nacist vyber z Total Commanderu pres %UL. Nic jsem nesmazal.", 4
        return
    }

    ; Del ma mazat primo jen na E: a jen kdyz bezi hlavni instance.
    ; Vse ostatni ma jit pres normalni TC delete (tj. podle TC pravidel/Kose).
    if !mainRunning {
        DebugDeleteLog("main OFF => TC normal delete")
        RunTotalCommanderNormalDelete(hwnd)
        return
    }

    if !AreAllPathsLocalForPermanentDelete(paths) {
        DebugDeleteLog("non-E path => TC normal delete")
        RunTotalCommanderNormalDelete(hwnd)
        return
    }

    DebugDeleteLog("E eligible => permanent delete")
    if DeletePathsPermanent(paths) {
        DebugDeleteLog("permanent delete OK")
        Sleep 80
        ; Bez rereadu panelu - v nekterych pripadech skakal panel na C:.
    } else {
        DebugDeleteLog("permanent delete failed")
    }
}

AreAnyPathsNetworkDrive(paths) {
    paths := NormalizeAndFilterPaths(paths)

    for , path in paths {
        root := GetPathRoot(path)

        if (root = "") {
            if IsNetworkPath(path) {
                return true
            }
            continue
        }

        try {
            driveType := StrLower(DriveGetType(root))
            if (driveType = "network") {
                return true
            }
        } catch {
            ; kdyz nejde zjistit typ, pokracuj dal
        }
    }

    return false
}

AreAllPathsOnProtectedDrives(paths) {
    paths := NormalizeAndFilterPaths(paths)
    if (paths.Length = 0)
        return false

    for , one in paths {
        p := Trim(one, " `t`r`n" . Chr(34))
        if !RegExMatch(p, "i)^([A-Z]):\\", &m)
            return false
        d := StrUpper(m[1])
        if !(d = "A" || d = "C" || d = "D" || d = "P" || d = "Y")
            return false
    }

    return true
}

DebugDeleteLog(msg) {
    global DEBUG_DELETE_LOG
    global DEBUG_DELETE_LOG_FILE

    if !DEBUG_DELETE_LOG {
        return
    }

    line := A_Now " | " msg "`n"
    try {
        logDir := RegExReplace(DEBUG_DELETE_LOG_FILE, "\\[^\\]*$")
        if (logDir != "" && !DirExist(logDir))
            DirCreate logDir
        FileAppend line, DEBUG_DELETE_LOG_FILE, "UTF-8"
    } catch {
        try FileAppend line, A_Temp "\del_debug.log", "UTF-8"
    }
}

RunTotalCommanderNormalDelete(hwnd) {
    if !hwnd {
        return false
    }

    try {
        WinActivate "ahk_id " hwnd
        WinWaitActive "ahk_id " hwnd, , 1
    }

    ; WM_USER+51 = 1075, cm_Delete = 908
    try {
        SendMessage 1075, 908, 0, , "ahk_id " hwnd
        return true
    } catch {
        return false
    }
}

; ============================================================
; HLAVNI SPUSTENI BEZ PARAMETRU
; ============================================================

SCRIPT_IS_MAIN_INSTANCE := true

CloseExistingMainInstance()
Sleep 300

StartMainMarker()

OnExit(CleanupOnExit)

DllCall("SetWindowText", "Ptr", A_ScriptHwnd, "Str", APP_TITLE)

SetupCombinedTrayMenu()
OnClipboardChange(ClipboardChanged)

TrayTip "AHK Delete + odkazy", "Zapnuto. TC Delete/tlacitko: lokalni disky trvale, sit/NAS normalne pres TC. Schránka URL -> anonymní Firefox zapnuta.", 4

SetTimer(CheckActiveWindow, 500)
SetTimer(UpdateIrfanViewTitles, 100)
SetTimer(UpdateVlcTitles, 250)
SetTimer(UpdateVlcFullscreenOsd, 500)

return

; ============================================================
; DIAGNOSTIKA VLC
; Ctrl + Alt + V
; ============================================================

^!v::DebugVlcPlaylist()

^!p::ToggleClipboardLinkScript()
^!q::ExitCombinedScript()

; ============================================================
; IRFANVIEW - RYCHLA AKTUALIZACE TITULKU PO PREPNUTI OBRAZKU
; ============================================================

#HotIf WinActive("ahk_exe i_view64.exe") || WinActive("ahk_exe i_view32.exe")

~WheelDown::RequestIrfanTitleRefresh()
~WheelUp::RequestIrfanTitleRefresh()
~Right::RequestIrfanTitleRefresh()
~Left::RequestIrfanTitleRefresh()
~Space::RequestIrfanTitleRefresh()
~Backspace::RequestIrfanTitleRefresh()
~PgDn::RequestIrfanTitleRefresh()
~PgUp::RequestIrfanTitleRefresh()
~Home::RequestIrfanTitleRefresh()
~End::RequestIrfanTitleRefresh()

#HotIf

RequestIrfanTitleRefresh() {
    SetTimer(IrfanTitleRefreshBurst, -10)
}

IrfanTitleRefreshBurst() {
    static busy := false
    static rerunRequested := false

    if busy {
        rerunRequested := true
        return
    }

    busy := true

    try {
        loop {
            rerunRequested := false

            UpdateIrfanViewTitles()
            Sleep 60
            UpdateIrfanViewTitles()
            Sleep 100
            UpdateIrfanViewTitles()
            Sleep 180
            UpdateIrfanViewTitles()
            Sleep 300
            UpdateIrfanViewTitles()
            Sleep 500
            UpdateIrfanViewTitles()
            Sleep 800
            UpdateIrfanViewTitles()

            if !rerunRequested {
                break
            }
        }
    }
    finally {
        busy := false
    }
}

; ============================================================
; ZJISTENI VYBRANYCH POLOZEK Z TOTAL COMMANDERU
; ============================================================

GetPathsFromTcListFile(listFile) {
    listFile := Trim(listFile, " `t`r`n" . Chr(34))

    if (listFile = "") {
        return []
    }

    if !FileExist(listFile) {
        return []
    }

    ; Total Commander muze %UL ulozit ruznym kodovanim.
    ; Vratime prvni variantu, ve ktere najdeme realne existujici cesty.
    encodings := ["UTF-8", "CP0", "UTF-16"]

    for , enc in encodings {
        try {
            text := FileRead(listFile, enc)
        } catch {
            continue
        }

        raw := ParsePathLinesFromText(text)
        paths := NormalizeAndFilterPaths(raw)

        if (paths.Length > 0) {
            return paths
        }
    }

    ; Posledni pokus bez explicitniho kodovani.
    try {
        text := FileRead(listFile)
        raw := ParsePathLinesFromText(text)
        return NormalizeAndFilterPaths(raw)
    } catch {
        return []
    }
}


GetSelectedPathsFromTC(hwnd := 0) {
    if !hwnd {
        hwnd := GetTotalCommanderHwnd()
    }

    if !hwnd {
        return []
    }

    rawPaths := []
    clipSaved := ClipboardAll()

    try {
        A_Clipboard := ""

        try {
            SendMessage 1075, 2018, 0, , "ahk_id " hwnd
        }

        clipText := WaitForClipboardText(800, 20)

        if (Trim(clipText) != "") {
            rawPaths := ParsePathLinesFromText(clipText)
        }

        if (rawPaths.Length = 0) {
            A_Clipboard := ""

            try WinActivate "ahk_id " hwnd
            try WinWaitActive "ahk_id " hwnd, , 0.5
            Sleep 60

            Send "^+c"

            clipText := WaitForClipboardText(800, 20)

            if (Trim(clipText) != "") {
                rawPaths := ParsePathLinesFromText(clipText)
            }
        }

        if (rawPaths.Length = 0) {
            A_Clipboard := ""

            try WinActivate "ahk_id " hwnd
            try WinWaitActive "ahk_id " hwnd, , 0.5
            Sleep 60

            Send "^c"

            if WaitForClipboardFiles(800, 20) {
                rawPaths := GetClipboardFilePaths()
            }
        }
    }
    finally {
        try A_Clipboard := clipSaved
    }

    return NormalizeAndFilterPaths(rawPaths)
}

WaitForClipboardText(maxMs := 800, pollMs := 20) {
    startTick := A_TickCount
    clipText := ""

    while ((A_TickCount - startTick) < maxMs) {
        try {
            clipText := A_Clipboard
        } catch {
            clipText := ""
        }

        if (Trim(clipText) != "") {
            return clipText
        }

        Sleep pollMs
    }

    return ""
}

WaitForClipboardFiles(maxMs := 800, pollMs := 20) {
    startTick := A_TickCount

    while ((A_TickCount - startTick) < maxMs) {
        try {
            if DllCall("IsClipboardFormatAvailable", "UInt", 15) {
                return true
            }
        }

        Sleep pollMs
    }

    return false
}

ParsePathLinesFromText(text) {
    result := []

    Loop Parse text, "`n", "`r" {
        onePath := Trim(A_LoopField, " `t`r`n" . Chr(34))

        if (onePath != "") {
            result.Push(onePath)
        }
    }

    return result
}

GetClipboardFilePaths() {
    paths := []

    if !DllCall("IsClipboardFormatAvailable", "UInt", 15) {
        return paths
    }

    if !DllCall("OpenClipboard", "Ptr", 0) {
        return paths
    }

    try {
        hDrop := DllCall("GetClipboardData", "UInt", 15, "Ptr")

        if !hDrop {
            return paths
        }

        count := DllCall("Shell32\DragQueryFileW", "Ptr", hDrop, "UInt", 0xFFFFFFFF, "Ptr", 0, "UInt", 0, "UInt")

        Loop count {
            index := A_Index - 1
            len := DllCall("Shell32\DragQueryFileW", "Ptr", hDrop, "UInt", index, "Ptr", 0, "UInt", 0, "UInt")

            if (len <= 0) {
                continue
            }

            buf := Buffer((len + 1) * 2, 0)
            DllCall("Shell32\DragQueryFileW", "Ptr", hDrop, "UInt", index, "Ptr", buf.Ptr, "UInt", len + 1, "UInt")
            path := StrGet(buf, "UTF-16")

            if (Trim(path) != "") {
                paths.Push(path)
            }
        }
    }
    finally {
        DllCall("CloseClipboard")
    }

    return paths
}

; ============================================================
; MAZANI - POUZE TRVALE MAZANI LOKALNICH CEST
; ============================================================

AreAllPathsLocalForPermanentDelete(paths) {
    paths := NormalizeAndFilterPaths(paths)

    if (paths.Length = 0) {
        return false
    }

    for , path in paths {
        ; Trvale mazani povol jen pokud cesta zacina E:\
        ; Vse ostatni (A:/Y:/C:/D:/P:, UNC, jine jednotky, relativni cesty)
        ; se netrvale maze pres Kos / fallback.
        resolved := path

        if !RegExMatch(resolved, "i)^E:\\") {
            return false
        }

        if IsDangerousRootPath(resolved) {
            return false
        }

        if !(FileExist(resolved) || DirExist(resolved)) {
            return false
        }

        if IsNetworkPath(resolved) {
            return false
        }

        root := GetPathRoot(resolved)

        if (root = "") {
            return false
        }

        try {
            driveType := DriveGetType(root)
        } catch {
            return false
        }

        driveType := StrLower(driveType)

        ; A zaroven pouze pokud jde o fixed disk.
        if (driveType != "fixed") {
            return false
        }
    }

    return true
}

DeletePathsPermanent(paths) {
    paths := NormalizeAndFilterPaths(paths)

    if (paths.Length = 0) {
        return false
    }

    okAll := true
    errorText := ""

    for , path in paths {
        try {
            DeleteOnePermanent(path)
        } catch as e {
            okAll := false
            errorText .= path "`n" e.Message "`n`n"
        }
    }

    if !okAll {
        MsgBox "Nektere polozky se nepodarilo trvale odstranit:`n`n" errorText, "AHK Delete - mazani selhalo", "Iconx"
    }

    return okAll
}

DeleteOnePermanent(path) {
    if IsDangerousRootPath(path) {
        throw Error("Nebezpecna cesta - koren disku nebo sdileni: " path)
    }

    if DirExist(path) {
        DirDelete path, true
        return
    }

    if FileExist(path) {
        FileDelete path
        return
    }

    throw Error("Cesta neexistuje: " path)
}

; ============================================================
; PREVOD SITOVE/MAPOVANE CESTY NA LOKALNI CESTU
; ============================================================

ResolveLocalNetworkPath(path) {
    global LOCAL_MAPPED_DRIVE_OVERRIDES

    p := Trim(path, " `t`r`n" . Chr(34))

    if (p = "") {
        return ""
    }

    ; Pokud to neni sitova cesta, neni co prevadet.
    if !IsNetworkPath(p) {
        return p
    }

    ; 1) Rucni override podle pismene disku.
    if RegExMatch(p, "i)^([A-Z]:)\\?(.*)$", &mDrive) {
        driveKey := StrUpper(mDrive[1])
        restAfterDrive := mDrive[2]

        if LOCAL_MAPPED_DRIVE_OVERRIDES.Has(driveKey) {
            localRoot := LOCAL_MAPPED_DRIVE_OVERRIDES[driveKey]

            if (restAfterDrive != "") {
                return PathCombine(localRoot, restAfterDrive)
            }

            return localRoot
        }
    }

    ; 2) Ziskat UNC cestu.
    uncPath := p

    if RegExMatch(p, "i)^([A-Z]:)\\?(.*)$", &mDrive2) {
        driveSpec := StrUpper(mDrive2[1])
        restAfterDrive := mDrive2[2]

        uncRoot := GetMappedDriveUncRoot(driveSpec)

        if (uncRoot = "") {
            return ""
        }

        if (restAfterDrive != "") {
            uncPath := PathCombine(uncRoot, restAfterDrive)
        } else {
            uncPath := uncRoot
        }
    }

    ; 3) Rozebrat UNC \\server\share\zbytek
    parts := ParseUncPath(uncPath)

    if !IsObject(parts) {
        return ""
    }

    if !IsLocalServerName(parts.Server) {
        return ""
    }

    localShareRoot := GetLocalPathForLocalShare(parts.Share)

    if (localShareRoot = "") {
        return ""
    }

    if (parts.Rest != "") {
        return PathCombine(localShareRoot, parts.Rest)
    }

    return localShareRoot
}

GetMappedDriveUncRoot(driveSpec) {
    driveSpec := Trim(driveSpec)

    if !RegExMatch(driveSpec, "i)^[A-Z]:$") {
        return ""
    }

    size := 32767
    buf := Buffer(size * 2, 0)

    result := DllCall(
        "mpr\WNetGetConnectionW",
        "Str", driveSpec,
        "Ptr", buf.Ptr,
        "UIntP", &size,
        "UInt"
    )

    if (result != 0) {
        return ""
    }

    return StrGet(buf, "UTF-16")
}

ParseUncPath(uncPath) {
    p := Trim(uncPath, " `t`r`n" . Chr(34))

    if !RegExMatch(p, "^\\\\([^\\]+)\\([^\\]+)\\?(.*)$", &m) {
        return 0
    }

    return {
        Server: m[1],
        Share: m[2],
        Rest: m[3]
    }
}

IsLocalServerName(serverName) {
    s := StrLower(Trim(serverName))

    if (s = "") {
        return false
    }

    if (s = "localhost" || s = "127.0.0.1" || s = "::1") {
        return true
    }

    computerName := StrLower(EnvGet("COMPUTERNAME"))

    if (computerName != "") {
        if (s = computerName) {
            return true
        }

        if InStr(s, computerName ".") = 1 {
            return true
        }
    }

    localIps := GetLocalIpAddresses()

    for , ip in localIps {
        if (s = StrLower(ip)) {
            return true
        }
    }

    return false
}

GetLocalIpAddresses() {
    result := []

    try {
        wmi := ComObject("WbemScripting.SWbemLocator")
        svc := wmi.ConnectServer(".", "root\cimv2")
        query := "Select IPAddress From Win32_NetworkAdapterConfiguration Where IPEnabled=True"

        for adapter in svc.ExecQuery(query) {
            try {
                for ip in adapter.IPAddress {
                    ipText := Trim(String(ip))

                    if (ipText != "") {
                        result.Push(ipText)
                    }
                }
            }
        }
    } catch {
    }

    return result
}

GetLocalPathForLocalShare(shareName) {
    shareName := Trim(shareName)

    if (shareName = "") {
        return ""
    }

    ; Administratorske sdileni typu D$ -> D:\
    if RegExMatch(shareName, "i)^([A-Z])\$$", &mAdmin) {
        return mAdmin[1] ":\"
    }

    shareEsc := StrReplace(shareName, "'", "''")

    try {
        wmi := ComObject("WbemScripting.SWbemLocator")
        svc := wmi.ConnectServer(".", "root\cimv2")
        query := "Select Name, Path From Win32_Share Where Name='" shareEsc "'"

        for share in svc.ExecQuery(query) {
            try {
                sharePath := Trim(String(share.Path))

                if (sharePath != "") {
                    return sharePath
                }
            }
        }
    } catch {
        return ""
    }

    return ""
}

IsNetworkPath(path) {
    p := Trim(path, " `t`r`n" . Chr(34))

    if RegExMatch(p, "^\\\\") {
        return true
    }

    root := GetPathRoot(p)

    if (root = "") {
        return false
    }

    try {
        driveType := DriveGetType(root)

        if (StrLower(driveType) = "network") {
            return true
        }
    } catch {
        return false
    }

    return false
}

GetPathDriveTypeText(path) {
    localResolved := ResolveLocalNetworkPath(path)

    if (localResolved != "" && localResolved != path && (FileExist(localResolved) || DirExist(localResolved))) {
        return "Network mapovany na lokalni cestu"
    }

    if IsNetworkPath(path) {
        return "Network / sitovy disk"
    }

    root := GetPathRoot(path)

    if (root = "") {
        return "nezjisteno"
    }

    try {
        return DriveGetType(root)
    } catch {
        return "nezjisteno"
    }
}



GetPathRoot(path) {
    p := Trim(path, " `t`r`n" . Chr(34))

    if RegExMatch(p, "i)^([A-Z]:\\)", &m) {
        return m[1]
    }

    if RegExMatch(p, "i)^(\\\\[^\\]+\\[^\\]+)", &m) {
        return m[1] "\"
    }

    return ""
}



GetLeafName(path) {
    SplitPath path, &leaf
    return leaf
}

PathCombine(base, child) {
    base := Trim(base, " `t`r`n" . Chr(34))
    child := Trim(child, " `t`r`n" . Chr(34))

    if (base = "") {
        return child
    }

    if (child = "") {
        return base
    }

    lastChar := SubStr(base, StrLen(base), 1)

    if (lastChar = "\" || lastChar = "/") {
        return base child
    }

    return base "\" child
}

; ============================================================
; OBNOVENI PANELU PO SMAZANI
; ============================================================

RefreshFileManager(hwnd := 0) {
    if !hwnd {
        try hwnd := WinGetID("A")
        catch {
            return
        }
    }

    if !hwnd {
        return
    }

    if IsTotalCommanderWindow(hwnd) {
        ; 540 = cm_RereadSource
        try {
            SendMessage 1075, 540, 0, , "ahk_id " hwnd
        }

        try WinActivate "ahk_id " hwnd
        return
    }

    if IsExplorerWindow(hwnd) {
        try {
            ControlSend "{F5}", , "ahk_id " hwnd
            return
        }
    }
}

IsTotalCommanderWindow(hwnd) {
    try exe := StrLower(WinGetProcessName("ahk_id " hwnd))
    catch {
        exe := ""
    }

    try class := WinGetClass("ahk_id " hwnd)
    catch {
        class := ""
    }

    return (
        class = "TTOTAL_CMD"
        || exe = "totalcmd64.exe"
        || exe = "totalcmd.exe"
    )
}

IsExplorerWindow(hwnd) {
    try class := WinGetClass("ahk_id " hwnd)
    catch {
        class := ""
    }

    return (
        class = "CabinetWClass"
        || class = "ExploreWClass"
    )
}

NormalizeAndFilterPaths(rawPaths) {
    result := []
    seen := Map()

    for , onePath in rawPaths {
        path := Trim(onePath, " `t`r`n" . Chr(34))

        if (path = "") {
            continue
        }

        if IsDangerousRootPath(path) {
            continue
        }

        if !(FileExist(path) || DirExist(path)) {
            continue
        }

        key := StrLower(path)

        if !seen.Has(key) {
            seen[key] := true
            result.Push(path)
        }
    }

    return result
}

IsDangerousRootPath(path) {
    p := Trim(path, " `t`r`n" . Chr(34))

    if RegExMatch(p, "i)^[A-Z]:\\?$") {
        return true
    }

    if RegExMatch(p, "i)^\\\\[^\\]+\\[^\\]+\\?$") {
        return true
    }

    if (p = "\" || p = "/" || p = "") {
        return true
    }

    return false
}

GetTotalCommanderHwnd() {
    hwnd := 0

    try {
        if WinActive("ahk_class TTOTAL_CMD") {
            hwnd := WinGetID("A")
        }
    }

    if !hwnd {
        try hwnd := WinExist("ahk_class TTOTAL_CMD")
    }

    if !hwnd {
        try hwnd := WinExist("ahk_exe TOTALCMD64.EXE")
    }

    if !hwnd {
        try hwnd := WinExist("ahk_exe TOTALCMD.EXE")
    }

    return hwnd
}

; ============================================================
; HLAVNI INSTANCE / MUTEX / STAVOVY SOUBOR
; ============================================================

GetOwnPid() {
    return DllCall("GetCurrentProcessId", "UInt")
}

StartMainMarker() {
    global MAIN_MUTEX_NAME
    global MAIN_MUTEX_HANDLE

    MAIN_MUTEX_HANDLE := DllCall(
        "CreateMutexW",
        "Ptr", 0,
        "Int", false,
        "Str", MAIN_MUTEX_NAME,
        "Ptr"
    )

    WriteMainStateFile()
    SetTimer(WriteMainStateFile, 1000)
}

CloseMainMutex() {
    global MAIN_MUTEX_HANDLE

    if MAIN_MUTEX_HANDLE {
        try DllCall("CloseHandle", "Ptr", MAIN_MUTEX_HANDLE)
        MAIN_MUTEX_HANDLE := 0
    }
}

IsMainMutexPresent() {
    global MAIN_MUTEX_NAME

    hMutex := DllCall(
        "OpenMutexW",
        "UInt", 0x00100000,
        "Int", false,
        "Str", MAIN_MUTEX_NAME,
        "Ptr"
    )

    if hMutex {
        DllCall("CloseHandle", "Ptr", hMutex)
        return true
    }

    return false
}

WriteMainStateFile() {
    global STATE_FILE

    currentPid := GetOwnPid()

    text := ""
    text .= "PID=" currentPid "`n"
    text .= "SCRIPT=" A_ScriptFullPath "`n"
    text .= "MODE=MAIN`n"
    text .= "UPDATED=" A_Now "`n"

    try {
        if FileExist(STATE_FILE) {
            FileDelete STATE_FILE
        }

        FileAppend text, STATE_FILE, "UTF-8"
    } catch {
        TrayTip "Tiché mazání", "Nepodařilo se zapsat stavový soubor.", 5
    }
}

DeleteMainStateFile() {
    global STATE_FILE

    try {
        if FileExist(STATE_FILE) {
            FileDelete STATE_FILE
        }
    }
}

CleanupOnExit(ExitReason, ExitCode) {
    SetTimer(WriteMainStateFile, 0)
    DeleteMainStateFile()
    CloseMainMutex()
    HideVlcOsd()
    HideClipboardToolTip()
}

IsMainInstanceEnabled(allowCurrent := false) {
    global SCRIPT_IS_MAIN_INSTANCE

    if (allowCurrent && SCRIPT_IS_MAIN_INSTANCE) {
        return true
    }

    ; Spolehlive povazuj hlavni instanci za bezici jen pokud existuje mutex.
    ; Stavovy soubor je jen diagnosticky a po padu/ukonceni muze kratce pretrvat.
    if IsMainMutexPresent() {
        return true
    }

    return false
}

DeletePathsToRecycleBin(paths) {
    paths := NormalizeAndFilterPaths(paths)

    if (paths.Length = 0) {
        return false
    }

    for , path in paths {
        recycleTarget := path

        ; Lokální override pro SUBST/mapovane jednotky (A:, Y:) i kdyz nejsou vyhodnocene jako sit.
        manualResolved := ResolveManualDriveOverride(path)
        if (manualResolved != "" && manualResolved != path) {
            recycleTarget := manualResolved
            DebugDeleteLog("recycle uses manual override | " path " => " recycleTarget)
        }

        ; U sitovych/mapovanych cest preferuj nejdriv lokalne rozresleny cil.
        ; To pomuze pro mapovani typu \\THISPC\share -> D:\share (lokalni Kos).
        if IsNetworkPath(path) {
            localResolved := ResolveLocalNetworkPath(path)

            if (localResolved != "" && localResolved != path) {
                recycleTarget := localResolved
                DebugDeleteLog("recycle prefers resolved target | " path " => " recycleTarget)
            }
        }

        try {
            FileRecycle recycleTarget
            continue
        } catch as e1 {
            ; U mapovanych sitovych cest zkus fallback na lokalni cil, pokud jde o lokalni share/mapovani.
            localResolved := ResolveLocalNetworkPath(path)

            if (localResolved != "" && localResolved != path) {
                try {
                    FileRecycle localResolved
                    DebugDeleteLog("recycle fallback via resolved path OK | " path " => " localResolved)
                    continue
                } catch as e2 {
                    DebugDeleteLog("recycle failed both original/resolved | " path " | e1=" e1.Message " | e2=" e2.Message)
                    return false
                }
            }

            DebugDeleteLog("recycle failed original path | " path " | e=" e1.Message)
            return false
        }
    }

    return true
}

ResolveManualDriveOverride(path) {
    global LOCAL_MAPPED_DRIVE_OVERRIDES

    p := Trim(path, " `t`r`n" . Chr(34))
    if !RegExMatch(p, "i)^([A-Z]:)\\?(.*)$", &m)
        return ""

    driveKey := StrUpper(m[1])
    rest := m[2]
    if !LOCAL_MAPPED_DRIVE_OVERRIDES.Has(driveKey)
        return ""

    localRoot := LOCAL_MAPPED_DRIVE_OVERRIDES[driveKey]
    return (rest = "") ? localRoot : PathCombine(localRoot, rest)
}


IsFreshMainStateFilePresent() {
    global STATE_FILE
    global MAIN_STATE_MAX_AGE_SECONDS

    if !FileExist(STATE_FILE) {
        return false
    }

    try {
        text := FileRead(STATE_FILE, "UTF-8")
    } catch {
        return false
    }

    state := ParseStateFile(text)

    if !state.Has("MODE") {
        return false
    }

    if (StrUpper(Trim(state["MODE"])) != "MAIN") {
        return false
    }

    if !state.Has("UPDATED") {
        return false
    }

    updated := Trim(state["UPDATED"])

    if !RegExMatch(updated, "^\d{14}$") {
        return false
    }

    ageSeconds := DateDiff(A_Now, updated, "Seconds")

    if (ageSeconds < 0) {
        ageSeconds := 0
    }

    if (ageSeconds > MAIN_STATE_MAX_AGE_SECONDS) {
        return false
    }

    return true
}

GetMainStateAgeText() {
    global STATE_FILE

    if !FileExist(STATE_FILE) {
        return "neexistuje"
    }

    try {
        text := FileRead(STATE_FILE, "UTF-8")
        state := ParseStateFile(text)

        if state.Has("UPDATED") {
            updated := Trim(state["UPDATED"])
            ageSeconds := DateDiff(A_Now, updated, "Seconds")

            if (ageSeconds < 0) {
                ageSeconds := 0
            }

            return "existuje, stáří " ageSeconds " s"
        }

        return "existuje, ale bez UPDATED"
    } catch {
        return "existuje, stáří nezjištěno"
    }
}

ParseStateFile(text) {
    stateMap := Map()

    Loop Parse text, "`n", "`r" {
        line := Trim(A_LoopField)

        if (line = "") {
            continue
        }

        pos := InStr(line, "=")

        if (pos <= 1) {
            continue
        }

        key := Trim(SubStr(line, 1, pos - 1))
        val := Trim(SubStr(line, pos + 1))

        if (key != "") {
            stateMap[key] := val
        }
    }

    return stateMap
}

CloseExistingMainInstance() {
    global APP_TITLE

    try {
        while WinExist(APP_TITLE " ahk_class AutoHotkey") {
            hwnd := WinExist(APP_TITLE " ahk_class AutoHotkey")

            if !hwnd {
                break
            }

            WinClose "ahk_id " hwnd
            WinWaitClose "ahk_id " hwnd, , 2
            Sleep 200
        }
    }
}

; ============================================================
; AUTO MAXIMALIZACE PRO VYBRANE PROGRAMY
; ============================================================

CheckActiveWindow() {
    static lastWinId := 0

    try {
        winId := WinGetID("A")
    } catch {
        return
    }

    if (winId = lastWinId) {
        return
    }

    try {
        winClass := WinGetClass("ahk_id " winId)
    } catch {
        winClass := ""
    }

    try {
        winExe := StrLower(WinGetProcessName("ahk_id " winId))
    } catch {
        winExe := ""
    }

    if (
        winClass = "CabinetWClass"
        || winClass = "ExploreWClass"
        || winClass = "Notepad"
        || winExe = "notepad.exe"
        || winExe = "mailclient.exe"
        || winExe = "onenote.exe"
    ) {
        try WinMaximize "ahk_id " winId
    }

    lastWinId := winId
}


; ============================================================
; IRFANVIEW - POZICE SOUBORU MISTO ZOOMU
; ============================================================

UpdateIrfanViewTitles() {
    ProcessIrfanViewWindows("ahk_exe i_view64.exe")
    ProcessIrfanViewWindows("ahk_exe i_view32.exe")
}

ProcessIrfanViewWindows(winCriteria) {
    hwndList := []

    try {
        hwndList := WinGetList(winCriteria)
    } catch {
        return
    }

    for , hwnd in hwndList {
        winTitle := "ahk_id " hwnd

        try {
            title := WinGetTitle(winTitle)
        } catch {
            continue
        }

        if (title = "") {
            continue
        }

        if InStr(title, "Properties/Settings") {
            continue
        }

        if !InStr(title, "IrfanView") {
            continue
        }

        positionText := GetIrfanViewPositionText(winTitle)

        if (positionText = "") {
            continue
        }

        cleanTitle := title
        cleanTitle := RegExReplace(cleanTitle, "\s*\(Zoom:[^)]+\)")
        cleanTitle := RegExReplace(cleanTitle, "\s+\[\d+\s*/\s*\d+\]\s*$")
        cleanTitle := RegExReplace(cleanTitle, "\s+\(\d+\s*/\s*\d+\)\s*$")

        newTitle := cleanTitle " (" positionText ")"

        if (title != newTitle) {
            try {
                WinSetTitle(newTitle, winTitle)
            }
        }
    }
}

GetIrfanViewPositionText(winTitle) {
    Loop 12 {
        partIndex := A_Index
        text := ""

        try {
            text := StatusBarGetText(partIndex, winTitle)
        } catch {
            text := ""
        }

        text := Trim(text)

        if RegExMatch(text, "(\d+)\s*/\s*(\d+)", &m) {
            return m[1] "/" m[2]
        }
    }

    return ""
}

; ============================================================
; VLC - TITULEK PLAYLISTU
; ============================================================

UpdateVlcTitles() {
    static lastReadTick := 0
    static lastState := 0

    now := A_TickCount

    if (!IsObject(lastState) || (now - lastReadTick >= 1000)) {
        state := GetVlcPlaylistPosition()

        if IsObject(state) {
            lastState := state
        } else {
            lastState := 0
        }

        lastReadTick := now
    }

    if !IsObject(lastState) {
        return
    }

    hwndList := []

    try {
        hwndList := WinGetList("ahk_exe vlc.exe")
    } catch {
        return
    }

    for , hwnd in hwndList {
        winTitle := "ahk_id " hwnd

        try {
            title := WinGetTitle(winTitle)
        } catch {
            continue
        }

        if (title = "") {
            continue
        }

        if !IsMainVlcWindowTitle(title) {
            continue
        }

        videoName := lastState.Name

        if (videoName = "") {
            videoName := GetVideoNameFromVlcWindowTitle(title)
        }

        if (videoName = "") {
            continue
        }

        newTitle := videoName " - VLC (" lastState.Index "/" lastState.Total ")"

        if (title != newTitle) {
            try {
                WinSetTitle(newTitle, winTitle)
            }
        }
    }
}

IsMainVlcWindowTitle(title) {
    if InStr(title, "Pokročilé možnosti") || InStr(title, "Předvolby") || InStr(title, "Preferences") {
        return false
    }

    if InStr(title, "Direct3D") || InStr(title, "Qt") || InStr(title, "Default IME") || InStr(title, "MSCTFIME") {
        return false
    }

    if RegExMatch(title, "\s+-\s+VLC\s+\(\d+/\d+\)\s*$") {
        return true
    }

    if InStr(title, "Multimediální přehrávač VLC") {
        return true
    }

    return false
}

GetVideoNameFromVlcWindowTitle(title) {
    cleanTitle := title

    cleanTitle := RegExReplace(cleanTitle, "\s+-\s+VLC\s+\(\d+/\d+\)\s*$")
    cleanTitle := RegExReplace(cleanTitle, "\s+-\s+.*VLC\s*$")

    return Trim(cleanTitle)
}

GetVlcPlaylistPosition() {
    playlistXml := VlcHttpGetXml("/requests/playlist.xml")

    if (playlistXml = "") {
        return 0
    }

    playlistDoc := LoadXmlDocument(playlistXml)

    if !IsObject(playlistDoc) {
        return 0
    }

    leaves := 0

    try {
        leaves := playlistDoc.selectNodes("//leaf")
    } catch {
        leaves := 0
    }

    if !IsObject(leaves) {
        return 0
    }

    total := leaves.length

    if (total <= 0) {
        return 0
    }

    index := 0
    currentName := ""

    Loop total {
        leaf := leaves.item(A_Index - 1)

        currentAttr := ""

        try {
            currentAttr := String(leaf.getAttribute("current"))
        } catch {
            currentAttr := ""
        }

        if (StrLower(Trim(currentAttr)) = "current") {
            index := A_Index

            try {
                currentName := String(leaf.getAttribute("name"))
            } catch {
                currentName := ""
            }

            break
        }
    }

    if (index <= 0) {
        currentPlid := GetVlcCurrentPlaylistId()

        if (currentPlid != "") {
            Loop total {
                leaf := leaves.item(A_Index - 1)

                leafId := ""

                try {
                    leafId := String(leaf.getAttribute("id"))
                } catch {
                    leafId := ""
                }

                if (leafId = currentPlid) {
                    index := A_Index

                    try {
                        currentName := String(leaf.getAttribute("name"))
                    } catch {
                        currentName := ""
                    }

                    break
                }
            }
        }
    }

    if (index <= 0) {
        return 0
    }

    currentName := Trim(currentName)

    return {
        Index: index,
        Total: total,
        Name: currentName
    }
}

GetVlcCurrentPlaylistId() {
    statusXml := VlcHttpGetXml("/requests/status.xml")

    if (statusXml = "") {
        return ""
    }

    statusDoc := LoadXmlDocument(statusXml)

    if !IsObject(statusDoc) {
        return ""
    }

    currentNode := 0

    try {
        currentNode := statusDoc.selectSingleNode("//currentplid")
    } catch {
        currentNode := 0
    }

    if !IsObject(currentNode) {
        return ""
    }

    return Trim(currentNode.text)
}

; ============================================================
; VLC - OSD CASU NA CELE OBRAZOVCE
; ============================================================

UpdateVlcFullscreenOsd() {
    global VLC_FULLSCREEN_TIME_OSD

    if !VLC_FULLSCREEN_TIME_OSD {
        HideVlcOsd()
        return
    }

    if !IsVlcFullscreenActive() {
        HideVlcOsd()
        return
    }

    state := GetVlcTimeState()

    if !IsObject(state) {
        HideVlcOsd()
        return
    }

    if (state.Length <= 0) {
        HideVlcOsd()
        return
    }

    elapsedText := FormatVlcSeconds(state.Time)
    remainingText := FormatVlcSeconds(state.Length - state.Time)
    lengthText := FormatVlcSeconds(state.Length)

    text := "Uplynulo: " elapsedText "   |   Zbývá: " remainingText "   |   Celkem: " lengthText

    ShowVlcOsd(text)
}

IsVlcFullscreenActive() {
    try hwnd := WinGetID("A")
    catch {
        return false
    }

    try exe := StrLower(WinGetProcessName("ahk_id " hwnd))
    catch {
        return false
    }

    if (exe != "vlc.exe") {
        return false
    }

    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    } catch {
        return false
    }

    try monitorCount := MonitorGetCount()
    catch {
        monitorCount := 1
    }

    cx := x + (w / 2)
    cy := y + (h / 2)

    Loop monitorCount {
        try {
            MonitorGet(A_Index, &ml, &mt, &mr, &mb)
        } catch {
            continue
        }

        if (cx >= ml && cx <= mr && cy >= mt && cy <= mb) {
            monW := mr - ml
            monH := mb - mt

            if (w >= monW - 40 && h >= monH - 40) {
                return true
            }
        }
    }

    return false
}

GetVlcTimeState() {
    statusXml := VlcHttpGetXml("/requests/status.xml")

    if (statusXml = "") {
        return 0
    }

    doc := LoadXmlDocument(statusXml)

    if !IsObject(doc) {
        return 0
    }

    timeValue := GetXmlNodeTextNumber(doc, "//time")
    lengthValue := GetXmlNodeTextNumber(doc, "//length")

    stateText := ""

    try {
        stateNode := doc.selectSingleNode("//state")

        if IsObject(stateNode) {
            stateText := Trim(stateNode.text)
        }
    } catch {
        stateText := ""
    }

    if (timeValue < 0) {
        timeValue := 0
    }

    if (lengthValue < 0) {
        lengthValue := 0
    }

    if (timeValue > lengthValue && lengthValue > 0) {
        timeValue := lengthValue
    }

    return {
        Time: timeValue,
        Length: lengthValue,
        State: stateText
    }
}

GetXmlNodeTextNumber(doc, xpath) {
    try {
        node := doc.selectSingleNode(xpath)

        if IsObject(node) {
            txt := Trim(node.text)

            if RegExMatch(txt, "^\d+$") {
                return Integer(txt)
            }
        }
    } catch {
    }

    return 0
}

FormatVlcSeconds(seconds) {
    seconds := Integer(seconds)

    if (seconds < 0) {
        seconds := 0
    }

    h := Floor(seconds / 3600)
    m := Floor(Mod(seconds, 3600) / 60)
    s := Mod(seconds, 60)

    if (h > 0) {
        return Format("{:02}:{:02}:{:02}", h, m, s)
    }

    return Format("{:02}:{:02}", m, s)
}

CreateVlcOsdIfNeeded() {
    global VLC_OSD_GUI
    global VLC_OSD_TEXT

    if IsObject(VLC_OSD_GUI) {
        return
    }

    VLC_OSD_GUI := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    VLC_OSD_GUI.BackColor := "111111"
    VLC_OSD_GUI.MarginX := 18
    VLC_OSD_GUI.MarginY := 10
    VLC_OSD_GUI.SetFont("s18 Bold cFFFFFF", "Segoe UI")
    VLC_OSD_TEXT := VLC_OSD_GUI.AddText("w620 Center", "")
}

ShowVlcOsd(text) {
    global VLC_OSD_GUI
    global VLC_OSD_TEXT
    global VLC_OSD_LAST_TEXT
    global VLC_OSD_POSITION
    global VLC_OSD_TOP_MARGIN
    global VLC_OSD_BOTTOM_MARGIN

    CreateVlcOsdIfNeeded()

    if (VLC_OSD_LAST_TEXT != text) {
        VLC_OSD_TEXT.Text := text
        VLC_OSD_LAST_TEXT := text
    }

    w := 660
    h := 58

    GetActiveWindowMonitorRect(&monLeft, &monTop, &monRight, &monBottom)

    monW := monRight - monLeft
    x := monLeft + Round((monW - w) / 2)

    if (StrLower(VLC_OSD_POSITION) = "bottom") {
        y := monBottom - VLC_OSD_BOTTOM_MARGIN
    } else {
        y := monTop + VLC_OSD_TOP_MARGIN
    }

    try {
        VLC_OSD_GUI.Show("NoActivate x" x " y" y " w" w " h" h)
        WinSetTransparent(215, "ahk_id " VLC_OSD_GUI.Hwnd)
    }
}

GetActiveWindowMonitorRect(&monLeft, &monTop, &monRight, &monBottom) {
    monLeft := 0
    monTop := 0
    monRight := A_ScreenWidth
    monBottom := A_ScreenHeight

    try hwnd := WinGetID("A")
    catch {
        return
    }

    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    } catch {
        return
    }

    cx := x + (w / 2)
    cy := y + (h / 2)

    try monitorCount := MonitorGetCount()
    catch {
        monitorCount := 1
    }

    Loop monitorCount {
        try {
            MonitorGet(A_Index, &ml, &mt, &mr, &mb)
        } catch {
            continue
        }

        if (cx >= ml && cx <= mr && cy >= mt && cy <= mb) {
            monLeft := ml
            monTop := mt
            monRight := mr
            monBottom := mb
            return
        }
    }
}

HideVlcOsd() {
    global VLC_OSD_GUI
    global VLC_OSD_LAST_TEXT

    if IsObject(VLC_OSD_GUI) {
        try VLC_OSD_GUI.Hide()
    }

    VLC_OSD_LAST_TEXT := ""
}

; ============================================================
; VLC HTTP A XML
; ============================================================

VlcHttpGetXml(endpoint) {
    global VLC_HTTP_HOST
    global VLC_HTTP_PORT
    global VLC_HTTP_PASSWORD

    if (Trim(VLC_HTTP_PASSWORD) = "") {
        return ""
    }

    url := "http://" VLC_HTTP_HOST ":" VLC_HTTP_PORT endpoint

    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", url, false)

        auth := "Basic " Base64Encode(":" VLC_HTTP_PASSWORD)
        http.SetRequestHeader("Authorization", auth)

        http.Send()

        if (http.Status = 401) {
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("GET", url, false)
            http.SetCredentials("", VLC_HTTP_PASSWORD, 0)
            http.Send()
        }

        if (http.Status != 200) {
            return ""
        }

        return http.ResponseText
    } catch {
        return ""
    }
}

LoadXmlDocument(xmlText) {
    try {
        doc := ComObject("MSXML2.DOMDocument.6.0")
        doc.async := false
        doc.setProperty("SelectionLanguage", "XPath")

        if !doc.loadXML(xmlText) {
            return 0
        }

        return doc
    } catch {
        return 0
    }
}

Base64Encode(text) {
    byteCount := StrPut(text, "UTF-8") - 1

    if (byteCount <= 0) {
        return ""
    }

    buf := Buffer(byteCount + 1, 0)
    StrPut(text, buf, byteCount + 1, "UTF-8")

    flags := 0x40000001
    chars := 0

    ok := DllCall(
        "Crypt32\CryptBinaryToStringW",
        "Ptr", buf.Ptr,
        "UInt", byteCount,
        "UInt", flags,
        "Ptr", 0,
        "UIntP", &chars
    )

    if !ok {
        return ""
    }

    out := ""
    VarSetStrCapacity(&out, chars)

    ok := DllCall(
        "Crypt32\CryptBinaryToStringW",
        "Ptr", buf.Ptr,
        "UInt", byteCount,
        "UInt", flags,
        "Str", out,
        "UIntP", &chars
    )

    if !ok {
        return ""
    }

    return Trim(out, "`r`n`t ")
}

DebugVlcPlaylist(*) {
    statusXml := VlcHttpGetXml("/requests/status.xml")
    playlistXml := VlcHttpGetXml("/requests/playlist.xml")
    state := GetVlcPlaylistPosition()
    timeState := GetVlcTimeState()

    vlcCount := 0
    titles := ""

    try {
        hwndList := WinGetList("ahk_exe vlc.exe")
        vlcCount := hwndList.Length

        for , hwnd in hwndList {
            try {
                titles .= WinGetTitle("ahk_id " hwnd) "`n"
            }
        }
    } catch {
        vlcCount := 0
    }

    msg := ""
    msg .= "VLC okna: " vlcCount "`n"
    msg .= "status.xml delka: " StrLen(statusXml) "`n"
    msg .= "playlist.xml delka: " StrLen(playlistXml) "`n"

    if IsObject(state) {
        msg .= "Playlist index: " state.Index "`n"
        msg .= "Playlist total: " state.Total "`n"
        msg .= "Playlist name: " state.Name "`n"
    } else {
        msg .= "Playlist pozice: NENALEZENA`n"
    }

    if IsObject(timeState) {
        msg .= "Cas: " FormatVlcSeconds(timeState.Time) "`n"
        msg .= "Delka: " FormatVlcSeconds(timeState.Length) "`n"
        msg .= "Zbyva: " FormatVlcSeconds(timeState.Length - timeState.Time) "`n"
        msg .= "Stav: " timeState.State "`n"
    } else {
        msg .= "Cas: NENALEZEN`n"
    }

    msg .= "`nFullscreen aktivni: " (IsVlcFullscreenActive() ? "ANO" : "NE") "`n"
    msg .= "`nHlavní instance běží: " (IsMainInstanceEnabled(true) ? "ANO" : "NE") "`n"
    msg .= "`nMutex hlavní instance: " (IsMainMutexPresent() ? "ANO" : "NE") "`n"
    msg .= "`nStavový soubor: " GetMainStateAgeText() "`n"
    msg .= "`nTitulky VLC oken:`n" titles

    MsgBox msg, "VLC debug", "Iconi"
}

; ============================================================
; SCHRANKA WINDOWS -> FIREFOX ANONYMNÍ OKNO
; ============================================================

SetupCombinedTrayMenu() {
    global ClipboardLinkEnabled

    try A_TrayMenu.Delete()

    if ClipboardLinkEnabled {
        A_TrayMenu.Add("Pozastavit predavani odkazu", ToggleClipboardLinkScript)
    } else {
        A_TrayMenu.Add("Zapnout predavani odkazu", ToggleClipboardLinkScript)
    }

    A_TrayMenu.Add("Diagnostika VLC", DebugVlcPlaylist)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Ukoncit cely skript", ExitCombinedScript)

    if ClipboardLinkEnabled {
        TraySetIcon("shell32.dll", 220)
    } else {
        TraySetIcon("shell32.dll", 109)
    }
}

ClipboardChanged(DataType) {
    global ClipboardLinkEnabled

    if !ClipboardLinkEnabled {
        return
    }

    ; 1 = text ve schrance
    if (DataType != 1) {
        return
    }

    SetTimer(ProcessClipboardUrl, -120)
}

ProcessClipboardUrl() {
    global LastClipboardUrl
    global LastClipboardUrlTime
    global ClipboardDuplicateBlockMs

    try {
        url := A_Clipboard
    } catch {
        return
    }

    url := CleanClipboardUrl(url)

    if !IsValidClipboardUrl(url) {
        return
    }

    now := A_TickCount

    if (url = LastClipboardUrl && now - LastClipboardUrlTime < ClipboardDuplicateBlockMs) {
        ClipboardShowInfo("Stejny odkaz preskocen.")
        return
    }

    LastClipboardUrl := url
    LastClipboardUrlTime := now

    SendUrlToPrivateFirefox(url)
}

CleanClipboardUrl(url) {
    url := Trim(url)

    ; Pokud je ve schrance vice radku, vezme se jen prvni.
    url := RegExReplace(url, "[\r\n].*$", "")

    ; Odstrani uvozovky na zacatku/konci.
    url := RegExReplace(url, "^[`"']+", "")
    url := RegExReplace(url, "[`"']+$", "")

    ; Odstrani pripadne < >.
    url := RegExReplace(url, "^<+", "")
    url := RegExReplace(url, ">+$", "")

    return Trim(url)
}

IsValidClipboardUrl(text) {
    text := Trim(text)

    if (text = "") {
        return false
    }

    if RegExMatch(text, "i)^https?://[^\s]+$") {
        return true
    }

    return false
}

SendUrlToPrivateFirefox(url) {
    global FirefoxExePath
    global ClipboardRestoreFocusDelayMs

    originalHwnd := 0

    try {
        originalHwnd := WinGetID("A")
    } catch {
        originalHwnd := 0
    }

    if !FileExist(FirefoxExePath) {
        ClipboardShowInfo("CHYBA:`nFirefox nebyl nalezen zde:`n" FirefoxExePath)
        return
    }

    ClipboardShowInfo("Odkaz zachycen.`nPredavam do anonymniho Firefoxu...")

    command := ClipboardQuote(FirefoxExePath) " -private-window " ClipboardQuote(url)

    try {
        Run(command, , "Hide")
    } catch {
        ClipboardShowInfo("CHYBA:`nNepodarilo se predat odkaz do anonymniho Firefoxu.")
        return
    }

    Sleep ClipboardRestoreFocusDelayMs
    RestoreOriginalWindowAfterClipboardUrl(originalHwnd)

    ClipboardShowInfo("Odkaz predan do anonymniho Firefoxu.`nFocus vracen zpet.")
}

RestoreOriginalWindowAfterClipboardUrl(originalHwnd) {
    global ClipboardRestoreFocusAttempts
    global ClipboardRestoreFocusAttemptDelayMs

    if !originalHwnd {
        return
    }

    Loop ClipboardRestoreFocusAttempts {
        if !WinExist("ahk_id " originalHwnd) {
            return
        }

        try WinActivate("ahk_id " originalHwnd)

        Sleep ClipboardRestoreFocusAttemptDelayMs

        try {
            activeHwnd := WinGetID("A")
        } catch {
            activeHwnd := 0
        }

        if (activeHwnd = originalHwnd) {
            return
        }
    }
}

ToggleClipboardLinkScript(*) {
    global ClipboardLinkEnabled

    ClipboardLinkEnabled := !ClipboardLinkEnabled
    SetupCombinedTrayMenu()

    if ClipboardLinkEnabled {
        ClipboardShowInfo("Predavani odkazu do anonymniho Firefoxu je zapnute.")
    } else {
        ClipboardShowInfo("Predavani odkazu do anonymniho Firefoxu je pozastavene.")
    }
}

ExitCombinedScript(*) {
    ClipboardShowInfo("Skript ukoncen.")
    Sleep 500
    ExitApp
}

ClipboardQuote(text) {
    return Chr(34) text Chr(34)
}

ClipboardShowInfo(text) {
    ToolTip(text)
    SetTimer(HideClipboardToolTip, -2500)
}

HideClipboardToolTip() {
    ToolTip()
}
