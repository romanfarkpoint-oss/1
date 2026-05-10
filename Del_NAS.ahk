#Requires AutoHotkey v2.0
#SingleInstance Off
#MaxThreadsPerHotkey 1
Persistent

; Del_NAS.ahk
; Rezim pro TC tlacitko /tcbutton:
; - D: nikdy trvale nemaze (normalni TC delete)
; - Y: maze do lokalniho Kose pres D:\Downloads
; - X:/Z: maze normalne pres Total Commander (SMB/NAS path -> NAS recycle podle nastaveni QNAP)

APP_TITLE := "AHK_DEL_NAS_MODE"
MAIN_MUTEX_NAME := "Local\\AHK_DEL_NAS_MODE_MUTEX"
MAIN_MUTEX_HANDLE := 0

arg1 := ""
arg2 := ""
if A_Args.Length >= 1
    arg1 := StrLower(Trim(A_Args[1]))
if A_Args.Length >= 2
    arg2 := Trim(A_Args[2])

if (arg1 = "/tcbutton" || arg1 = "tcbutton") {
    HandleTcDelete(arg2)
    ExitApp
}

; Hlavni trvala instance (ikona u hodin) pro NAS rezim.
StartMainMarker()
OnExit(CleanupOnExit)
try DllCall("SetWindowText", "Ptr", A_ScriptHwnd, "Str", APP_TITLE)
TrayTip "AHK Del NAS", "NAS rezim zapnut. Zavri ikonu pro vypnuti.", 4
return

HandleTcDelete(listFileArg) {
    hwnd := WinExist("ahk_class TTOTAL_CMD")
    if !hwnd
        return

    ; Kdyz trvala NAS instance nebezi, nech mazani na standardnim TC.
    if !IsMainNasInstanceRunning() {
        RunTcNormalDelete(hwnd)
        return
    }

    paths := GetPathsFromTcListFile(listFileArg)
    if (paths.Length = 0) {
        RunTcNormalDelete(hwnd)
        return
    }

    if AreAllOnDrive(paths, "Y:") {
        if DeleteViaLocalRecycle(paths, "D:\\Downloads")
            return
    }

    ; X:/Z:/D: i vse ostatni nech na normalnim TC mazani.
    RunTcNormalDelete(hwnd)
}

AreAllOnDrive(paths, driveRoot) {
    for , p in paths {
        if !RegExMatch(p, "i)^" RegExReplace(driveRoot, "([\\:\.\+\*\?\[\]\(\)\{\}\|\^\$])", "\\$1"))
            return false
    }
    return paths.Length > 0
}

DeleteViaLocalRecycle(paths, localRoot) {
    for , p in paths {
        rel := RegExReplace(p, "i)^Y:\\?")
        target := localRoot
        if (rel != "")
            target := localRoot "\\" rel
        try FileRecycle target
        catch
            return false
    }
    return true
}

RunTcNormalDelete(hwnd) {
    try WinActivate "ahk_id " hwnd
    try WinWaitActive "ahk_id " hwnd, , 1
    try SendMessage 1075, 908, 0, , "ahk_id " hwnd
}

StartMainMarker() {
    global MAIN_MUTEX_NAME
    global MAIN_MUTEX_HANDLE
    MAIN_MUTEX_HANDLE := DllCall("CreateMutexW", "Ptr", 0, "Int", false, "Str", MAIN_MUTEX_NAME, "Ptr")
}

IsMainNasInstanceRunning() {
    global MAIN_MUTEX_NAME

    hMutex := DllCall("OpenMutexW", "UInt", 0x00100000, "Int", false, "Str", MAIN_MUTEX_NAME, "Ptr")
    if hMutex {
        DllCall("CloseHandle", "Ptr", hMutex)
        return true
    }
    return false
}

CleanupOnExit(*) {
    global MAIN_MUTEX_HANDLE
    if MAIN_MUTEX_HANDLE {
        try DllCall("CloseHandle", "Ptr", MAIN_MUTEX_HANDLE)
        MAIN_MUTEX_HANDLE := 0
    }
}

GetPathsFromTcListFile(listFile) {
    paths := []
    listFile := Trim(listFile, " `t`r`n" . Chr(34))
    if (listFile = "" || !FileExist(listFile))
        return paths

    for , enc in ["UTF-8", "CP0", "UTF-16"] {
        try txt := FileRead(listFile, enc)
        catch {
            continue
        }
        for line in StrSplit(txt, ["`r`n", "`n", "`r"]) {
            p := Trim(line, " `t`r`n" . Chr(34))
            if (p != "")
                paths.Push(p)
        }
        if (paths.Length > 0)
            return paths
    }

    return paths
}
