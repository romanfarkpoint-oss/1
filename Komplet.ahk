#Requires AutoHotkey v2.0

; A: a Y: už nepřemapovávat na lokální cesty.
; Pro test se nechávají jako síťové mapy/UNC.

TC_DELETE_COMMAND := "em_ahk_delete"
TC_DELETE_EXE := A_AhkPath
TC_DELETE_PARAM_KOMPLET := '"' A_ScriptFullPath '" /tcbutton %UL'
TC_DELETE_PARAM_DEL := '"P:\Programy\zSkripty\AHK\Já\Del.ahk" /tcbutton %UL'
TC_DELETE_DEBUG_LOG := "P:\Programy\zSkripty\AHK\Já\Logy\komplet_tc_delete.log"
TC_DELETE_DEBUG_ENABLED := true
KOMPLET_MAIN_LOG := A_Temp "\komplet_main_lifecycle.log"

; TC tlacitko/hotkey: Komplet.ahk /tcbutton %UL
if (A_Args.Length >= 1) {
    arg1 := StrLower(Trim(A_Args[1]))
    arg2 := (A_Args.Length >= 2) ? Trim(A_Args[2]) : ""

    if (arg1 = "/tcbutton" || arg1 = "tcbutton") {
        try {
            TcDeleteLog("tcbutton start | arg2=" arg2)
            HandleTcDeleteAyRecycle(arg2)
            TcDeleteLog("tcbutton end OK")
        } catch as e {
            TcDeleteLog("tcbutton ERROR | " e.Message)
        }
        ExitApp
    }
}

; Jen hlavni trvala instance ma menit TC mapovani.
LogKompletMain("MAIN START pid=" DllCall("GetCurrentProcessId", "UInt"))
OnExit(KompletOnExit)
SetTcDeleteToKomplet()

SetTcDeleteToKomplet() {
    global TC_DELETE_COMMAND, TC_DELETE_EXE, TC_DELETE_PARAM_KOMPLET
    WriteTcDeleteCommand(TC_DELETE_EXE, TC_DELETE_PARAM_KOMPLET)
}

RestoreTcDeleteToDel(*) {
    global TC_DELETE_EXE, TC_DELETE_PARAM_DEL
    WriteTcDeleteCommand(TC_DELETE_EXE, TC_DELETE_PARAM_DEL)
}

KompletOnExit(exitReason, exitCode) {
    LogKompletMain("MAIN EXIT pid=" DllCall("GetCurrentProcessId", "UInt") " | reason=" exitReason " | code=" exitCode)
    RestoreTcDeleteToDel()
}

WriteTcDeleteCommand(cmdExe, cmdParam) {
    global TC_DELETE_COMMAND
    tcUsercmdIni := GetTcUsercmdIniPath()
    if (tcUsercmdIni = "")
        return

    section := TC_DELETE_COMMAND
    try IniWrite cmdExe, tcUsercmdIni, section, "cmd"
    try IniWrite cmdParam, tcUsercmdIni, section, "param"
    try IniWrite "AHK Delete", tcUsercmdIni, section, "menu"
}

GetTcUsercmdIniPath() {
    candidates := [
        A_AppData "\GHISLER\usercmd.ini",
        A_AppData "\Ghisler\usercmd.ini",
        "P:\Programy\Total Commander\usercmd.ini",
        "P:\Programy\Total Commander\INI\usercmd.ini"
    ]

    for , one in candidates {
        if FileExist(one)
            return one
    }

    return ""
}

; === Township kontrola ===
SetTimer(CheckTownship, 5000)
CheckTownship() {
    townshipPID := ProcessExist("TS_Prod.exe")
    if (townshipPID) {
        RunWait "P:\Programy\zSkripty\Ostatni\nircmd.exe setappvolume TS_Prod.exe 0.07"
    }
}

; === Homescapes kontrola ===
SetTimer(CheckHomescapes, 5000)
CheckHomescapes() {
    HomescapesPID := ProcessExist("Homescapes.exe")
    if (HomescapesPID) {
        RunWait "P:\Programy\zSkripty\Ostatni\nircmd.exe setappvolume Homescapes.exe 0.24"
    }
}

; === Winamp ovládání ===
#HotIf WinExist("ahk_class Winamp v1.x")
^#Right::PostMessage(0x111, 40048, 0, , "ahk_class Winamp v1.x")  ; Další skladba
^#Left::PostMessage(0x111, 40044, 0, , "ahk_class Winamp v1.x")   ; Předchozí skladba
^#Up::PostMessage(0x111, 40058, 0, , "ahk_class Winamp v1.x")     ; Hlasitost nahoru
^#Down::PostMessage(0x111, 40059, 0, , "ahk_class Winamp v1.x")   ; Hlasitost dolů
^#Space::PostMessage(0x111, 40046, 0, , "ahk_class Winamp v1.x")  ; Pauza
#HotIf

#SingleInstance Off
CoordMode "Mouse", "Screen"
WinTitle := "ahk_exe HD-Player.exe"

SetTimer(ClickMaximizeBlueStacks, 1000)

ClickMaximizeBlueStacks() {
    global WinTitle
    static done := false
    static t0 := 0
    delay := 700

    if WinExist(WinTitle) {
        if !done {
            if !t0
                t0 := A_TickCount
            if (A_TickCount - t0 < delay)
                return

            hwnd := WinExist(WinTitle)
            WinActivate("ahk_id " hwnd)
            Sleep 500

            WinGetPos &x, &y, &w, &h, "ahk_id " hwnd

            ; dvojklik doprostred horni listy okna
            MouseMove x + (w // 2), y + 10, 0
            Sleep 100
            Click "left", 2

            done := true
        }
    } else {
        done := false
        t0 := 0
    }
}
; === Detekce Logitech zařízení a ztlumení/zapnutí zvuku ===
SetTimer(CheckLogitechDevice, 1000)
logitechFound := true
CheckLogitechDevice() {
    global logitechFound
    result := []
    try {
        shell := ComObject("WbemScripting.SWbemLocator")
        service := shell.ConnectServer(".", "root\cimv2")
        query := "Select * From Win32_PnPEntity Where Name Like '%Logitech%'"
        for device in service.ExecQuery(query)
            result.Push(device.Name)
    }
    isPresent := result.Length > 0
    if (logitechFound and !isPresent) {
        Run "P:\Programy\zSkripty\Ostatni\nircmd.exe mutesysvolume 1", , "Hide"
    } else if (!logitechFound and isPresent) {
        Run "P:\Programy\zSkripty\Ostatni\nircmd.exe mutesysvolume 0", , "Hide"
    }
    logitechFound := isPresent
}

; === Watch folder for screenshots a přejmenování ===
global folderToWatch := "B:\zPC\"
global alreadyRenamed := Map()
SetTimer(WatchFolder, 1000)
WatchFolder() {
    static filePattern := "Snímek obrazovky*.png"
    global alreadyRenamed, folderToWatch

    for file in DirWatch(folderToWatch, filePattern) {
        if alreadyRenamed.Has(file)
            continue
        alreadyRenamed[file] := true
        fullPath := folderToWatch file
        try {
            fileTime := FileGetTime(fullPath, "C")
            FormatTimeString := FormatTime(fileTime, "yyyy-MM-dd HH mm ss")
            newName := folderToWatch FormatTimeString ".png"
            counter := 1
            while FileExist(newName)
                newName := folderToWatch FormatTimeString " (" counter++ ").png"
            FileMove(fullPath, newName)
        } catch {
            ; možná není soubor ještě uložen
        }
    }
}
DirWatch(dir, pattern) {
    files := []
    Loop Files dir . pattern {
        files.Push(A_LoopFileName)
    }
    return files
}

; === Auto maximalizace pro Notepad, Průzkumník, CGM, eM Client, OneNote a Teams ===
SetTimer(CheckActiveWindow, 500)

CheckActiveWindow() {
    try {
        winId := WinGetID("A")
    } catch {
        return
    }

    winClass := WinGetClass("ahk_id " winId)

    if (winClass = "CabinetWClass")
    || (winClass = "Notepad")
    || WinActive("ahk_exe cgm.exe")
    || WinActive("ahk_exe MailClient.exe")
    || WinActive("ahk_exe ONENOTE.EXE")
    || WinActive("ahk_exe ms-teams.exe")
    {
        WinMaximize("ahk_id " winId)
    }
}
#Requires AutoHotkey v2.0
#SingleInstance Off

; === Rambox start, maximalizace a zavření přes Alt+F4 ===
; === Rambox start, maximalizace a zavření ===
; Rambox autostart zrusen na pozadani.
; SetTimer(StartRambox, -1000)

StartRambox() {
    RamboxExe := "C:\Program Files\Rambox\Rambox.exe"
    RamboxWin := "ahk_exe Rambox.exe"

    ; Spustit Rambox, pokud ještě neběží
    if !WinExist(RamboxWin) {
        try Run RamboxExe
        catch {
            return
        }
    }

    ; Čekej na okno Ramboxu
    if !WinWait(RamboxWin, , 40)
        return

    ; Po startu Windows mu dej čas na donačtení
    Sleep 1000

    ; Znovu najdi aktuální okno Ramboxu
    hwnd := WinExist(RamboxWin)
    if !hwnd
        return

    WinTitle := "ahk_id " hwnd

    ; Aktivace
    try WinActivate WinTitle
    try WinWaitActive WinTitle, , 10

    ; Maximalizace
    hwnd := WinExist(RamboxWin)
    if !hwnd
        return

    WinTitle := "ahk_id " hwnd

    try {
        if (WinGetMinMax(WinTitle) != 1) {
            CoordMode "Mouse", "Window"

            try WinActivate WinTitle
            Sleep 500

            ; dvojklik vlevo nahoře
            try Click 25, 14, 2

            ; čekej max. 5 sekund
            Loop 50 {
                hwnd := WinExist(RamboxWin)
                if !hwnd
                    return

                WinTitle := "ahk_id " hwnd

                try {
                    if (WinGetMinMax(WinTitle) = 1)
                        break
                }

                Sleep 100
            }

            ; fallback
            hwnd := WinExist(RamboxWin)
            if hwnd {
                WinTitle := "ahk_id " hwnd
                try {
                    if (WinGetMinMax(WinTitle) != 1)
                        WinMaximize WinTitle
                }
            }
        }
    }

    ; Po maximalizaci počkej 2 sekundy
    Sleep 2000

    ; DŮLEŽITÉ:
    ; těsně před zavřením znovu najdi aktuální okno Ramboxu
    hwnd := WinExist(RamboxWin)
    if !hwnd
        return

    WinTitle := "ahk_id " hwnd

    ; Pokus 1: WinClose
    try WinClose WinTitle

    Sleep 1000

    ; Pokus 2: systémový příkaz Zavřít
    hwnd := WinExist(RamboxWin)
    if hwnd {
        WinTitle := "ahk_id " hwnd
        try PostMessage 0x112, 0xF060,,, WinTitle
    }

    Sleep 1000

    ; Pokus 3: skutečné Alt+F4 do aktuálního Rambox okna
    hwnd := WinExist(RamboxWin)
    if hwnd {
        WinTitle := "ahk_id " hwnd

        try WinActivate WinTitle
        try WinWaitActive WinTitle, , 5

        Sleep 300
        Send "!{F4}"
    }

    return
}


#Requires AutoHotkey v2.0

GetCfg() {
    static cfg := Map(
        "scrcpyDir", "P:\Programy\zSkripty\Mobil\Scrcpy",
        "scrcpyExe", "P:\Programy\zSkripty\Mobil\Scrcpy\scrcpy.exe",
        "scrcpyVbs", "P:\Programy\zSkripty\Mobil\Scrcpy\scrcpy-noconsole.vbs",
        "adbExe",    "P:\Programy\zSkripty\Mobil\ADB\adb.exe",
        "serial",    "R5CY83GTXXD",
        "args",      "-s R5CY83GTXXD --turn-screen-off --stay-awake"
    )
    return cfg
}

GetState() {
    static state := Map("hwnd", 0)
    return state
}

InitScrcpyEnv() {
    cfg := GetCfg()
    EnvSet("ADB", cfg["adbExe"])
}

GetScrcpyWindow() {
    DetectHiddenWindows True

    if WinExist("ahk_exe scrcpy.exe ahk_class SDL_app") {
        hwnd := WinGetID("ahk_exe scrcpy.exe ahk_class SDL_app")
        DetectHiddenWindows False
        return hwnd
    }

    if WinExist("ahk_exe scrcpy.exe") {
        hwnd := WinGetID("ahk_exe scrcpy.exe")
        DetectHiddenWindows False
        return hwnd
    }

    DetectHiddenWindows False
    return 0
}

BringToFrontAndFix(hwnd) {
    if !hwnd
        return

    DetectHiddenWindows True

    try WinShow("ahk_id " hwnd)
    try WinRestore("ahk_id " hwnd)

    sw := A_ScreenWidth
    sh := A_ScreenHeight

    try {
        WinGetPos(&xCur, &yCur, &w, &h, "ahk_id " hwnd)
    } catch {
        xCur := 0
        yCur := 0
        w := 900
        h := 600
    }

    if (!w || !h) {
        w := 900
        h := 600
    }

    if (xCur + w < 0 || yCur + h < 0 || xCur > sw || yCur > sh) {
        x := (sw - w) // 2
        y := (sh - h) // 2
        try WinMove(x, y, , , "ahk_id " hwnd)
    }

    try WinActivate("ahk_id " hwnd)

    DetectHiddenWindows False
}

StartScrcpy() {
    cfg := GetCfg()
    state := GetState()

    state["hwnd"] := GetScrcpyWindow()
    if state["hwnd"] {
        BringToFrontAndFix(state["hwnd"])
        return
    }

    if !FileExist(cfg["adbExe"]) {
        MsgBox "Nenalezen adb.exe:`n" cfg["adbExe"]
        return
    }

    if !FileExist(cfg["scrcpyExe"]) {
        MsgBox "Nenalezen scrcpy.exe:`n" cfg["scrcpyExe"]
        return
    }

    InitScrcpyEnv()

    try {
        if FileExist(cfg["scrcpyVbs"]) {
            Run('wscript.exe "' cfg["scrcpyVbs"] '" ' cfg["args"], cfg["scrcpyDir"])
        } else {
            Run('"' cfg["scrcpyExe"] '" ' cfg["args"], cfg["scrcpyDir"])
        }
    } catch as e {
        MsgBox "Nepodařilo se spustit scrcpy.`n`n" e.Message
        return
    }

    DetectHiddenWindows True

    if WinWait("ahk_exe scrcpy.exe ahk_class SDL_app", , 10) {
        state["hwnd"] := WinGetID("ahk_exe scrcpy.exe ahk_class SDL_app")
        BringToFrontAndFix(state["hwnd"])
        DetectHiddenWindows False
        return
    }

    if WinWait("ahk_exe scrcpy.exe", , 3) {
        state["hwnd"] := WinGetID("ahk_exe scrcpy.exe")
        BringToFrontAndFix(state["hwnd"])
        DetectHiddenWindows False
        return
    }

    DetectHiddenWindows False
    MsgBox "scrcpy se nespustilo."
}

ToggleScrcpy() {
    state := GetState()
    state["hwnd"] := GetScrcpyWindow()

    if !state["hwnd"] {
        StartScrcpy()
        return
    }

    DetectHiddenWindows True

    try {
        style := WinGetStyle("ahk_id " state["hwnd"])
    } catch {
        state["hwnd"] := 0
        DetectHiddenWindows False
        StartScrcpy()
        return
    }

    WS_VISIBLE := 0x10000000

    if (style & WS_VISIBLE) {
        try WinHide("ahk_id " state["hwnd"])
    } else {
        BringToFrontAndFix(state["hwnd"])
    }

    DetectHiddenWindows False
}

F9:: {
    ToggleScrcpy()
}

^!m:: {
    ToggleScrcpy()
}

#SingleInstance Off

$^v:: {
    ; Kdyz jsou ve schrance soubory/slozky, nezasahuj do toho
    if HasFileClipboard() {
        SendEvent "^v"
        return
    }

    ; Kdyz tam neni text, take jen normalne vloz
    if !HasTextClipboard() {
        SendEvent "^v"
        return
    }

    originalClip := ClipboardAll()
    text := A_Clipboard

    ; odstrani nadbytecne prazdne radky na konci
    text := RegExReplace(text, "(\r\n|\n|\r)+$", "")

    ; pokud chces nechat na konci prave jeden Enter, pouzij misto radku vyse toto:
    ; text := RegExReplace(text, "(\r\n|\n|\r)+$", "`r`n")

    A_Clipboard := text
    ClipWait 0.5

    SendEvent "^v"
    Sleep 100

    A_Clipboard := originalClip
}

HasTextClipboard() {
    ; CF_UNICODETEXT = 13
    return DllCall("IsClipboardFormatAvailable", "UInt", 13)
}

HasFileClipboard() {
    ; CF_HDROP = 15
    return DllCall("IsClipboardFormatAvailable", "UInt", 15)
}

HandleTcDeleteAyRecycle(listFileArg) {
    auditId := "AUDIT-" A_Now "-" DllCall("GetCurrentProcessId", "UInt")
    hwnd := WinExist("ahk_class TTOTAL_CMD")
    TcDeleteLog("Handle start | hwnd=" hwnd)
    paths := GetPathsFromTcListFileSimple(listFileArg)
    TcDeleteLog("audit begin | id=" auditId " | listFile=" listFileArg)
    TcDeleteLog("paths count=" paths.Length)
    for idx, p in paths {
        TcDeleteLog("path=" p)
        TcDeleteLog("audit path | id=" auditId " | idx=" idx " | path=" p)
    }

    if (paths.Length = 0) {
        TcDeleteLog("paths empty -> TC normal delete")
        RunTcNormalDeleteSimple(hwnd)
        return
    }

    plan := BuildKompletDeletePlan(paths)
    TcDeleteLog("delete plan | recycle=" plan.Recycle.Length " | tc=" plan.Tc.Length)

    if (plan.Recycle.Length > 0) {
        if DeletePathsToRecycleBinSimple(plan.Recycle) {
            TcDeleteLog("recycle delete OK")
        } else {
            TcDeleteLog("recycle delete FAILED")
        }
    }

    ; V Komplet modu se nic nema mazat trvale.
    ; NAS/B/M/T/X/Z + fallback (a cokoliv mimo recycle bucket) nechame na TC.
    if (plan.Tc.Length > 0) {
        if plan.BDriveTouched {
            LogBRecycleBinDeepSnapshot("before_tc_delete")
        }
        RunTcNormalDeleteSimple(hwnd)
        if plan.BDriveTouched {
            LogBRecycleBinDeepSnapshot("after_tc_delete")
        }
    }

    if plan.BDriveTouched {
        TcDeleteLog("audit b-drive touched | id=" auditId)
        LogBRecycleBinStateKomplet()
    }
    TcDeleteLog("audit end | id=" auditId " | recycle=" plan.Recycle.Length " | tc=" plan.Tc.Length)
}

LogBRecycleBinDeepSnapshot(stage := "") {
    recycleRoot := "B:\zPC\$RECYCLE.BIN"
    stamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    TcDeleteLog("B recycle DEEP begin | stage=" stage " | ts=" stamp " | root=" recycleRoot)
    if !DirExist(recycleRoot) {
        TcDeleteLog("B recycle DEEP | root missing")
        return
    }

    count := 0
    totalBytes := 0
    Loop Files, recycleRoot "\*", "FR" {
        count += 1
        sz := A_LoopFileSize + 0
        totalBytes += sz
        mod := ""
        crt := ""
        attr := ""
        try mod := FileGetTime(A_LoopFilePath, "M")
        try crt := FileGetTime(A_LoopFilePath, "C")
        try attr := FileGetAttrib(A_LoopFilePath)
        TcDeleteLog("B recycle DEEP item | path=" A_LoopFilePath " | size=" sz " | attr=" attr " | ctime=" crt " | mtime=" mod)
    }
    TcDeleteLog("B recycle DEEP end | files=" count " | bytes=" totalBytes)
}

BuildKompletDeletePlan(paths) {
    plan := {Recycle: [], Tc: [], BDriveTouched: false}
    for , raw in paths {
        p := Trim(raw, " `t`r`n" . Chr(34))
        if (p = "")
            continue
        bucket := ClassifyKompletDeleteBucket(p)
        if (bucket = "recycle")
            plan.Recycle.Push(p)
        else
            plan.Tc.Push(p)
        if RegExMatch(p, "i)^B:\\")
            plan.BDriveTouched := true
    }
    return plan
}

ClassifyKompletDeleteBucket(path) {
    if !RegExMatch(path, "i)^([A-Z]):\\", &m)
        return "recycle"

    d := StrUpper(m[1])
    if (d = "B" || d = "M" || d = "T" || d = "X" || d = "Z")
        return "tc"
    if (d = "A" || d = "Y")
        return "recycle"
    if (d = "C" || d = "D" || d = "P" || d = "E")
        return "recycle"

    ; Ostatni sitove/UNC a nove jednotky (napr. L:) standardne do Windows Kose.
    return "recycle"
}

DeletePathsToRecycleBinSimple(paths) {
    for , path in paths {
        target := ResolveAyToLocalPath(path)
        if (target = "")
            target := path
        try {
            FileRecycle target
            TcDeleteLog("recycle OK | " path " => " target)
        } catch as e {
            TcDeleteLog("recycle FAIL | " path " => " target " | " e.Message)
            return false
        }
    }
    return true
}

LogBRecycleBinStateKomplet() {
    recycleRoot := "B:\zPC\$RECYCLE.BIN"
    TcDeleteLog("B recycle snapshot begin | root=" recycleRoot)
    if !DirExist(recycleRoot) {
        TcDeleteLog("B recycle snapshot | root missing")
        return
    }
    count := 0
    totalBytes := 0
    Loop Files, recycleRoot "\*", "FR" {
        count += 1
        totalBytes += A_LoopFileSize
        if (count <= 60)
            TcDeleteLog("B recycle item | " A_LoopFilePath " | size=" A_LoopFileSize)
    }
    TcDeleteLog("B recycle snapshot end | files=" count " | bytes=" totalBytes)
}

DeletePathSilentNoPrompt(path) {
    p := Trim(path, " `t`r`n" . Chr(34))
    if (p = "")
        return false

    try {
        if DirExist(p) {
            DirDelete p, true
            return true
        }
        if FileExist(p) {
            FileDelete p
            return true
        }
    } catch {
        return false
    }

    return false
}

TcDeleteLog(msg) {
    global TC_DELETE_DEBUG_LOG
    global TC_DELETE_DEBUG_ENABLED
    if !TC_DELETE_DEBUG_ENABLED
        return
    line := A_Now " | " msg "`n"
    try {
        logDir := RegExReplace(TC_DELETE_DEBUG_LOG, "\\[^\\]*$")
        if (logDir != "" && !DirExist(logDir))
            DirCreate logDir
        FileAppend line, TC_DELETE_DEBUG_LOG, "UTF-8"
    } catch {
        try FileAppend line, A_Temp "\komplet_tc_delete.log", "UTF-8"
    }
}

LogKompletMain(msg) {
    global KOMPLET_MAIN_LOG
    line := A_Now " | " msg "`n"
    try FileAppend line, KOMPLET_MAIN_LOG, "UTF-8"
}

ResolveAyToLocalPath(path) {
    p := Trim(path, " `t`r`n" . Chr(34))

    if RegExMatch(p, "i)^A:\\?(.*)$", &mA) {
        rest := mA[1]
        return (rest = "") ? "C:\Users\R\A" : "C:\Users\R\A\" rest
    }

    if RegExMatch(p, "i)^Y:\\?(.*)$", &mY) {
        rest := mY[1]
        return (rest = "") ? "D:\Downloads" : "D:\Downloads\" rest
    }

    return ""
}

ResolveAyToUncPath(path) {
    p := Trim(path, " `t`r`n" . Chr(34))

    if RegExMatch(p, "i)^A:\\?(.*)$", &mA) {
        rest := mA[1]
        return (rest = "") ? "\\VELIN\Users\R\A" : "\\VELIN\Users\R\A\" rest
    }
    if RegExMatch(p, "i)^Y:\\?(.*)$", &mY) {
        rest := mY[1]
        return (rest = "") ? "\\VELIN\Downloads" : "\\VELIN\Downloads\" rest
    }
    return ""
}

IsNetworkPathSimple(path) {
    p := Trim(path, " `t`r`n" . Chr(34))
    if (SubStr(p, 1, 2) = "\\")
        return true
    try {
        if RegExMatch(p, "i)^([A-Z]:\\)", &m)
            return (StrLower(DriveGetType(m[1])) = "network")
    } catch {
    }
    return false
}


GetPathsFromTcListFileSimple(listFile) {
    out := []
    listFile := Trim(listFile, " `t`r`n" . Chr(34))
    if (listFile = "" || !FileExist(listFile))
        return out

    for , enc in ["UTF-8", "CP0", "UTF-16"] {
        try txt := FileRead(listFile, enc)
        catch {
            continue
        }

        for line in StrSplit(txt, ["`r`n", "`n", "`r"]) {
            p := Trim(line, " `t`r`n" . Chr(34))
            if (p != "")
                out.Push(p)
        }

        if (out.Length > 0)
            return out
    }

    return out
}

RunTcNormalDeleteSimple(hwnd) {
    if !hwnd
        return
    try WinActivate "ahk_id " hwnd
    try WinWaitActive "ahk_id " hwnd, , 1
    SetTimer(AutoConfirmTcDeleteDialog, 80)
    try SendMessage 1075, 908, 0, , "ahk_id " hwnd ; cm_Delete
    Sleep 250
    SetTimer(AutoConfirmTcDeleteDialog, 0)
}

AutoConfirmTcDeleteDialog() {
    for title in ["Odstranit soubor", "Delete file"] {
        hwnd := WinExist(title " ahk_class #32770")
        if hwnd {
            try ControlSend "{Enter}", , "ahk_id " hwnd
        }
    }
}
