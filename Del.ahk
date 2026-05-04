#Requires AutoHotkey v2.0
#SingleInstance Off
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
; LOCAL_MAPPED_DRIVE_OVERRIDES["Y:"] := "D:\Downloads"
; LOCAL_MAPPED_DRIVE_OVERRIDES["Z:"] := "E:\Sdilene"
;
; ============================================================

LOCAL_MAPPED_DRIVE_OVERRIDES := Map()
LOCAL_MAPPED_DRIVE_OVERRIDES["Y:"] := "D:\Downloads"

; ============================================================
; DEL PRO TOTAL COMMANDER
; ============================================================
;
; usercmd.ini:
;
; [em_trvale_smazat]
; cmd=P:\Programy\AutoHotkey\v2\AutoHotkey64.exe
; param="P:\Programy\zSkripty\AHK\Já\Del.ahk" /tcbutton %UL
; menu=Trvalé smazání přes AHK
;
; Chovani:
; - hlavni trvala instance AHK bezi:
;     - vyber jen ze skutecne lokalnich disku = trvale smazani bez Kose
;     - NAS / skutecna sitova cesta / smiseny vyber = normalni mazani Total Commanderu
; - hlavni trvala instance AHK nebezi:
;     - klavesa Del se nechytá vubec
;     - tlacitko TC pres /tcbutton pouze posle normalni Delete do Total Commanderu
; - AHK nikdy nepouziva nahradni kos _AHK_Kos.
;
; ============================================================

APP_TITLE := "AHK_DEL_JAKO_SHIFT_DEL_TC_EXPLORER"

MAIN_MUTEX_NAME := "Local\AHK_DEL_TC_EXPLORER_MAIN_MUTEX"
MAIN_MUTEX_HANDLE := 0

STATE_FILE := A_Temp "\AHK_DEL_JAKO_SHIFT_DEL_TC_EXPLORER.state"
SCRIPT_IS_MAIN_INSTANCE := false
MAIN_STATE_MAX_AGE_SECONDS := 4

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
VLC_OSD_GUI := 0
VLC_OSD_TEXT := 0
VLC_OSD_LAST_TEXT := ""

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
; JEDNORAZOVE VOLANI Z TLACITKA TOTAL COMMANDERU
; ============================================================
;
; Logika:
; - kdyz hlavni trvala instance tohoto AHK BEZI:
;     - pokud jsou vsechny vybrane polozky skutecne lokalni, smaze je trvale bez Kose
;     - pokud je mezi nimi NAS / skutecna sitova cesta, pusti se normalni mazani TC
; - kdyz hlavni trvala instance tohoto AHK NEBEZI:
;     - pusti se normalni mazani TC, jako kdyby zadny AHK nebyl
;
; AHK v teto vetvi NIKDY nepouziva nahradni kos.
;

if (arg1 = "/tcbutton" || arg1 = "tcbutton") {
    mainIsRunning := IsMainInstanceEnabled(false)
    hwnd := GetTotalCommanderHwnd()

    if !hwnd {
        ExitApp
    }

    ; Pokud hlavni instance nebezi, tlacitko se ma chovat normalne jako TC Delete.
    if !mainIsRunning {
        SendNormalDeleteToTotalCommander(hwnd)
        ExitApp
    }

    paths := []

    if (arg2 != "") {
        paths := GetPathsFromTcListFile(arg2)
    }

    if (paths.Length = 0) {
        try WinActivate "ahk_id " hwnd
        try WinWaitActive "ahk_id " hwnd, , 2
        Sleep 80
        paths := GetSelectedPathsFromTC(hwnd)
    }

    ; Hlavni instance bezi, ale trvale mazeme jen skutecne lokalni cesty.
    ; NAS / sitove cesty nechame na normalnim TC mazani.
    normalizedPaths := NormalizeAndFilterPaths(paths)
    localDeletePaths := GetLocalPermanentDeletePaths(normalizedPaths)

    if (normalizedPaths.Length > 0 && localDeletePaths.Length = normalizedPaths.Length) {
        DeletePathsNoAsk(localDeletePaths, true)
        Sleep 150
        RefreshFileManager(hwnd)
    } else {
        SendNormalDeleteToTotalCommander(hwnd)
    }

    ExitApp
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

TrayTip "Tiché mazání", "Zapnuto. Pouze lokální položky v TC maže trvale. NAS/síť nechává normálně na TC.", 3

SetTimer(CheckActiveWindow, 500)
SetTimer(UpdateIrfanViewTitles, 100)
SetTimer(UpdateVlcTitles, 250)
SetTimer(UpdateVlcFullscreenOsd, 500)

return

; ============================================================
; DELETE V TOTAL COMMANDERU
; ============================================================

#HotIf IsTotalCommanderDeleteHotkeyContext()

$*Del::TcDeleteByKeyboard()
$*NumpadDel::TcDeleteByKeyboard()

#HotIf

TcDeleteByKeyboard() {
    static busy := false

    if busy {
        return
    }

    busy := true

    try {
        hwnd := GetTotalCommanderHwnd()

        if !hwnd {
            PassDeleteThroughFromHotkey()
            return
        }

        paths := GetSelectedPathsFromTC(hwnd)
        normalizedPaths := NormalizeAndFilterPaths(paths)
        localDeletePaths := GetLocalPermanentDeletePaths(normalizedPaths)

        ; Trvale a bez Kose mazeme jen tehdy, kdyz jsou vsechny vybrane polozky
        ; skutecne lokalni. Jakmile je ve vyberu NAS/sitova cesta, pusti se normalni TC Delete.
        if (normalizedPaths.Length > 0 && localDeletePaths.Length = normalizedPaths.Length) {
            DeletePathsNoAsk(localDeletePaths, true)
            Sleep 150
            RefreshFileManager(hwnd)
        } else {
            PassDeleteThroughFromHotkey()
        }
    } finally {
        busy := false
    }
}

PassDeleteThroughFromHotkey() {
    ; Diky $ u hotkey se tento Send nechyti znovu stejnou hotkey v tomto skriptu.
    ; {Blind} zachova Shift/Ctrl/Alt, takze napr. Shift+Del zustane Shift+Del.
    if InStr(A_ThisHotkey, "NumpadDel") {
        SendEvent "{Blind}{NumpadDel}"
    } else {
        SendEvent "{Blind}{Delete}"
    }
}

SendNormalDeleteToTotalCommander(hwnd := 0) {
    if !hwnd {
        hwnd := GetTotalCommanderHwnd()
    }

    if !hwnd {
        return
    }

    try WinActivate "ahk_id " hwnd
    try WinWaitActive "ahk_id " hwnd, , 1
    Sleep 50

    ; ControlSend neposila globalni fyzickou klavesu, takze zbytecne nespousti
    ; nasi hlavni Del hotkey. TC si mazani zpracuje normalne sam.
    try {
        ControlSend "{Delete}", , "ahk_id " hwnd
    } catch {
        SendEvent "{Delete}"
    }
}

IsTotalCommanderDeleteHotkeyContext() {
    if IsTextInputFocused() {
        return false
    }

    try hwnd := WinGetID("A")
    catch {
        return false
    }

    return IsTotalCommanderWindow(hwnd)
}

IsTextInputFocused() {
    try ctrl := ControlGetFocus("A")
    catch {
        return false
    }

    if (ctrl = "") {
        return false
    }

    return RegExMatch(ctrl, "i)(Edit|TEdit|TMyEdit|ComboBox)")
}

; ============================================================
; DIAGNOSTIKA TOTAL COMMANDERU
; Ctrl + Alt + D
; ============================================================

^!d::TestTcSelectionDebug()

TestTcSelectionDebug() {
    hwnd := GetTotalCommanderHwnd()

    t1 := A_TickCount

    if hwnd {
        paths := GetSelectedPathsFromTC(hwnd)
    } else {
        paths := []
    }

    elapsed := A_TickCount - t1

    msg := ""
    msg .= "Total Commander hwnd: " hwnd "`n"
    msg .= "Nalezeno položek: " paths.Length "`n"
    msg .= "Čas zjištění: " elapsed " ms`n"
    msg .= "Hlavní instance běží: " (IsMainInstanceEnabled(true) ? "ANO" : "NE") "`n"
    msg .= "Mutex hlavní instance: " (IsMainMutexPresent() ? "ANO" : "NE") "`n"
    msg .= "Stavový soubor: " STATE_FILE "`n"
    msg .= "Stavový soubor stav: " GetMainStateAgeText() "`n`n"

    for , p in paths {
        localResolved := ResolveLocalNetworkPath(p)

        msg .= p "`n"
        msg .= "Typ disku: " GetPathDriveTypeText(p) "`n"

        if (localResolved != "") {
            msg .= "Převod na lokální cestu: " localResolved "`n"
        } else {
            msg .= "Převod na lokální cestu: nezjištěn`n"
        }

        msg .= "Náhradní koš: nepoužívá se`n`n"
    }

    MsgBox msg, "TC debug", "Iconi"
}

; ============================================================
; DIAGNOSTIKA VLC
; Ctrl + Alt + V
; ============================================================

^!v::DebugVlcPlaylist()

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
    result := []

    listFile := Trim(listFile, " `t`r`n" . Chr(34))

    if (listFile = "") {
        return result
    }

    if !FileExist(listFile) {
        return result
    }

    text := ""

    try {
        text := FileRead(listFile, "UTF-16")
    } catch {
        try {
            text := FileRead(listFile, "UTF-8")
        } catch {
            try {
                text := FileRead(listFile)
            } catch {
                return result
            }
        }
    }

    Loop Parse text, "`n", "`r" {
        onePath := Trim(A_LoopField, " `t`r`n" . Chr(34))

        if (onePath != "") {
            result.Push(onePath)
        }
    }

    return NormalizeAndFilterPaths(result)
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
; MAZANI
; ============================================================

DeletePathsNoAsk(paths, permanentDelete) {
    ; AHK v teto verzi nikdy nepouziva Kos ani nahradni Kos.
    ; Tato funkce je urcena jen pro trvale smazani lokalnich polozek.
    if !permanentDelete {
        return false
    }

    paths := GetLocalPermanentDeletePaths(paths)

    if (paths.Length = 0) {
        return false
    }

    okAll := true
    failedMessages := []

    for , path in paths {
        try {
            DeleteOnePermanent(path)
        } catch as e {
            okAll := false
            failedMessages.Push(BuildDeleteFailureMessage(path, e, true))
        }
    }

    if !okAll {
        ShowDeleteFailureMessages(failedMessages)
    }

    return okAll
}

DeleteOnePermanent(path) {
    path := ResolvePathForPermanentDelete(path)

    if (path = "") {
        throw Error("Tato cesta neni povolena pro tiche trvale mazani. Pravdepodobne jde o NAS/sitovou cestu nebo nebezpecny koren disku.")
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

DeleteOneToRecycleBin(path) {
    ; Zamerne vypnuto.
    ; Kdyz hlavni AHK nebezi, ma se pouzit normalni mazani Total Commanderu / Windows,
    ; nikoli AHK presun do Kose a uz vubec ne nahradni Kos.
    throw Error("AHK presun do Kose je vypnuty. Pro normalni mazani se pouziva primo Total Commander.")
}

GetLocalPermanentDeletePaths(paths) {
    normalized := NormalizeAndFilterPaths(paths)
    result := []
    seen := Map()

    for , path in normalized {
        localPath := ResolvePathForPermanentDelete(path)

        if (localPath = "") {
            continue
        }

        key := StrLower(localPath)

        if !seen.Has(key) {
            seen[key] := true
            result.Push(localPath)
        }
    }

    return result
}

ResolvePathForPermanentDelete(path) {
    p := Trim(path, " `t`r`n" . Chr(34))

    if (p = "") {
        return ""
    }

    ; Mapovany disk, ktery ve skutecnosti vede na tento pocitac,
    ; prevede na opravdovou lokalni cestu. Priklad: Y:\ -> D:\Downloads.
    localResolved := ResolveLocalNetworkPath(p)

    if (localResolved != "" && (FileExist(localResolved) || DirExist(localResolved))) {
        p := localResolved
    }

    if IsDangerousRootPath(p) {
        return ""
    }

    if !(FileExist(p) || DirExist(p)) {
        return ""
    }

    if !IsLocalPathForPermanentDelete(p) {
        return ""
    }

    return p
}

IsLocalPathForPermanentDelete(path) {
    p := Trim(path, " `t`r`n" . Chr(34))

    if (p = "") {
        return false
    }

    ; UNC cesta je lokalni jen tehdy, pokud ji ResolveLocalNetworkPath dokazal prevest.
    ; Pokud jsme porad na UNC, nechame ji normalnimu TC mazani.
    if RegExMatch(p, "^\\\\") {
        return false
    }

    root := GetPathRoot(p)

    if (root = "") {
        return false
    }

    try {
        driveType := StrLower(DriveGetType(root))
    } catch {
        return false
    }

    ; Network nikdy nemazeme tise/trvale pres AHK.
    if (driveType = "network") {
        return false
    }

    ; Fixed/removable/ramdisk/CDROM jsou lokalni typy z pohledu Windows.
    ; Prakticky se bude mazat jen pokud FileExist/DirExist projde.
    return true
}

ResolvePathForDeleteOperation(path) {
    ; Kvuli diagnostice chyb vracime stejnou cestu, se kterou se opravdu mazalo.
    localPath := ResolvePathForPermanentDelete(path)

    if (localPath != "") {
        return localPath
    }

    return Trim(path, " `t`r`n" . Chr(34))
}

BuildDeleteFailureMessage(path, errorObj, permanentDelete) {
    operationText := "trvale odstranit"
    resolvedPath := ResolvePathForDeleteOperation(path)
    lockText := GetLockingProcessText(resolvedPath)

    msg := "Nepodařilo se " operationText " tuto položku:`n"
    msg .= resolvedPath "`n`n"

    if (lockText != "") {
        msg .= "Položku pravděpodobně používá tento proces:`n"
        msg .= lockText "`n`n"
        msg .= "Ukonči uvedený program nebo v něm zavři daný soubor/složku a akci opakuj."
    } else {
        msg .= "Nepodařilo se zjistit konkrétní proces, který položku drží.`n"
        msg .= "Může ji držet systém, antivirus, Total Commander/plugin, náhled, síťové připojení, nebo chybí oprávnění."
    }

    msg .= "`n`nDetail chyby:`n" errorObj.Message

    return msg
}

ShowDeleteFailureMessages(messages) {
    if (messages.Length = 0) {
        return
    }

    maxShown := 5
    text := ""

    for index, oneMsg in messages {
        if (index > maxShown) {
            remaining := messages.Length - maxShown
            text .= "`n`n... a dalších " remaining " položek."
            break
        }

        if (text != "") {
            text .= "`n`n------------------------------------------------------------`n`n"
        }

        text .= oneMsg
    }

    MsgBox text, "Tiché mazání - položku nelze odstranit", "Iconx"
}

; ============================================================
; ZJISTENI PROCESU, KTERY DRZI SOUBOR/SLOZKU
; ============================================================

GetLockingProcessText(path) {
    resources := GetRestartManagerResources(path, 250)

    if (resources.Length = 0) {
        return ""
    }

    processes := GetRestartManagerLockingProcesses(resources)

    if (processes.Length = 0) {
        return ""
    }

    lines := []
    seen := Map()

    for , proc in processes {
        key := String(proc.PID)

        if seen.Has(key) {
            continue
        }

        seen[key] := true

        line := "- " proc.Name "  [PID " proc.PID "]"

        if (proc.ExePath != "") {
            line .= "`n  " proc.ExePath
        }

        lines.Push(line)
    }

    return JoinLines(lines)
}

GetRestartManagerResources(path, maxFiles := 250) {
    result := []
    p := Trim(path, " `t`r`n" . Chr(34))

    if (p = "") {
        return result
    }

    if DirExist(p) {
        ; Zkusime registrovat i samotnou slozku. Nekdy ji drzi proces jako adresar.
        result.Push(p)

        ; Restart Manager ale nejlepe hlasi konkretni soubory uvnitr slozky.
        Loop Files, p "\*", "FR" {
            result.Push(A_LoopFileFullPath)

            if (result.Length >= maxFiles) {
                break
            }
        }

        return result
    }

    if FileExist(p) {
        result.Push(p)
        return result
    }

    return result
}

GetRestartManagerLockingProcesses(paths) {
    result := []

    if (paths.Length = 0) {
        return result
    }

    hSession := 0
    sessionKey := Buffer(256 * 2, 0)

    rmStart := DllCall(
        "Rstrtmgr\RmStartSession",
        "UIntP", &hSession,
        "UInt", 0,
        "Ptr", sessionKey.Ptr,
        "UInt"
    )

    if (rmStart != 0 || hSession = 0) {
        return result
    }

    try {
        pointerArray := Buffer(paths.Length * A_PtrSize, 0)
        stringBuffers := []

        for index, onePath in paths {
            chars := StrPut(onePath, "UTF-16")
            b := Buffer(chars * 2, 0)
            StrPut(onePath, b.Ptr, chars, "UTF-16")
            stringBuffers.Push(b)
            NumPut("Ptr", b.Ptr, pointerArray, (index - 1) * A_PtrSize)
        }

        rmRegister := DllCall(
            "Rstrtmgr\RmRegisterResources",
            "UInt", hSession,
            "UInt", paths.Length,
            "Ptr", pointerArray.Ptr,
            "UInt", 0,
            "Ptr", 0,
            "UInt", 0,
            "Ptr", 0,
            "UInt"
        )

        if (rmRegister != 0) {
            return result
        }

        needed := 0
        count := 0
        rebootReasons := 0

        rmList := DllCall(
            "Rstrtmgr\RmGetList",
            "UInt", hSession,
            "UIntP", &needed,
            "UIntP", &count,
            "Ptr", 0,
            "UIntP", &rebootReasons,
            "UInt"
        )

        ERROR_MORE_DATA := 234

        if (rmList != ERROR_MORE_DATA || needed = 0) {
            return result
        }

        count := needed
        RM_PROCESS_INFO_SIZE := 668
        infoBuf := Buffer(RM_PROCESS_INFO_SIZE * count, 0)

        rmList := DllCall(
            "Rstrtmgr\RmGetList",
            "UInt", hSession,
            "UIntP", &needed,
            "UIntP", &count,
            "Ptr", infoBuf.Ptr,
            "UIntP", &rebootReasons,
            "UInt"
        )

        if (rmList != 0) {
            return result
        }

        Loop count {
            base := infoBuf.Ptr + ((A_Index - 1) * RM_PROCESS_INFO_SIZE)
            pid := NumGet(base, 0, "UInt")
            appName := StrGet(base + 12, 256, "UTF-16")

            procInfo := GetProcessInfoByPid(pid, appName)
            result.Push(procInfo)
        }
    } finally {
        try DllCall("Rstrtmgr\RmEndSession", "UInt", hSession, "UInt")
    }

    return result
}

GetProcessInfoByPid(pid, fallbackName := "") {
    name := Trim(fallbackName)
    exePath := ""

    try {
        wmi := ComObject("WbemScripting.SWbemLocator")
        svc := wmi.ConnectServer(".", "root\cimv2")
        query := "Select Name, ExecutablePath From Win32_Process Where ProcessId=" pid

        for proc in svc.ExecQuery(query) {
            try {
                if (Trim(String(proc.Name)) != "") {
                    name := Trim(String(proc.Name))
                }
            }

            try {
                if (Trim(String(proc.ExecutablePath)) != "") {
                    exePath := Trim(String(proc.ExecutablePath))
                }
            }

            break
        }
    } catch {
    }

    if (name = "") {
        name := "neznámý proces"
    }

    return {
        PID: pid,
        Name: name,
        ExePath: exePath
    }
}

JoinLines(lines) {
    text := ""

    for , line in lines {
        if (text != "") {
            text .= "`n"
        }

        text .= line
    }

    return text
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

GetCustomRecycleRoot(path) {
    return "NEPOUZIVA SE"
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

GetRelativePathFromRoot(path) {
    p := Trim(path, " `t`r`n" . Chr(34))
    root := GetPathRoot(p)

    if (root = "") {
        return GetLeafName(p)
    }

    if (SubStr(StrLower(p), 1, StrLen(root)) = StrLower(root)) {
        return SubStr(p, StrLen(root) + 1)
    }

    return GetLeafName(p)
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
        try {
            WinActivate "ahk_id " hwnd
            WinWaitActive "ahk_id " hwnd, , 1
            Sleep 120
            Send "{F2}"
            Sleep 120
            return
        }
        catch {
            try {
                SendMessage 1075, 540, 0, , "ahk_id " hwnd
                return
            }
        }
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
}

IsMainInstanceEnabled(allowCurrent := false) {
    global SCRIPT_IS_MAIN_INSTANCE

    if (allowCurrent && SCRIPT_IS_MAIN_INSTANCE) {
        return true
    }

    if IsMainMutexPresent() {
        return true
    }

    if IsFreshMainStateFilePresent() {
        return true
    }

    return false
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
    try {
        winId := WinGetID("A")
    } catch {
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

    CreateVlcOsdIfNeeded()

    if (VLC_OSD_LAST_TEXT != text) {
        VLC_OSD_TEXT.Text := text
        VLC_OSD_LAST_TEXT := text
    }

    w := 660
    h := 58
    x := Round((A_ScreenWidth - w) / 2)
    y := A_ScreenHeight - 125

    try {
        VLC_OSD_GUI.Show("NoActivate x" x " y" y " w" w " h" h)
        WinSetTransparent(215, "ahk_id " VLC_OSD_GUI.Hwnd)
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

DebugVlcPlaylist() {
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