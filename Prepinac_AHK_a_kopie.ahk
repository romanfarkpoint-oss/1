#Requires AutoHotkey v2.0
#SingleInstance Force
DetectHiddenWindows True

DEL_SCRIPT := "P:\Programy\zSkripty\AHK\Já\Del.ahk"
KOMPLET_SCRIPT := "P:\Programy\zSkripty\AHK\Já\Komplet.ahk"
AHK_EXE := A_AhkPath
STATE_FILE := A_Temp "\ahk_prepinac_state.txt" ; format: mode|pid
LOG_FILE := "P:\Programy\zSkripty\AHK\Já\Logy + prepinac\Testovaci soubory\prepinac_log.txt"
LOG_ENABLED := true

SOURCE_FOLDER := "P:\Programy\zSkripty\AHK\Já\Logy + prepinac\Testovaci soubory\"
SOURCE_FILES := ["wcx_ftp.ini", "vertical.br2"]
TARGET_DIRS := [
    "A:\Desktop\A\\",
    "B:\zPC\B\\",
    "C:\C\\",
    "D:\EaseUS_VideoDownloader\D\\",
    "E:\E\\",
    "M:\01 Česká\Bezinky\m\\",
    "P:\P\\",
    "T:\01 Filmy\t\\",
    "Y:\Y\\",
    "X:\02 Licence + návody\X\\",
    "Z:\02 Šárka\Z\\"
]

RECYCLE_DIRS_FULL_DELETE := [
    "Z:\02 Šárka\@Recycle\\",
    "Z:\08 TV\@Recycle\\"
]

RECYCLE_DIR_SINGLE_DELETE := "Z:\01 Já\@Recycle\Soukromé + instalačky\"
HARD_DELETE_DIR := "P:\Programy\zSkripty\AHK\Já\Logy\"

main() {
    Log("=== START ===")
    ToggleScripts()
    CopyTestFilesIfMissing()
    ClearRecycleTargets()
    DeleteHardFolder(HARD_DELETE_DIR)
    EmptyWindowsRecycleBin()
    Log("=== END OK ===")
    TrayTip "AHK přepínač", "Hotovo: přepnuto, zkopírováno, vyčištěno.", 4
    Sleep 1200
    ExitApp
}

ToggleScripts() {
    global DEL_SCRIPT, KOMPLET_SCRIPT, AHK_EXE, STATE_FILE
    lastMode := ""
    lastPid := 0
    ReadState(&lastMode, &lastPid)

    if (lastPid > 0) && ProcessExist(lastPid) {
        try ProcessClose lastPid
        Sleep 250
        if (lastMode = "del") {
            StartAndSaveState(KOMPLET_SCRIPT, "komplet")
            Log("Switch by saved pid | Del(pid=" lastPid ") -> Komplet")
            return
        } else if (lastMode = "komplet") {
            StartAndSaveState(DEL_SCRIPT, "del")
            Log("Switch by saved pid | Komplet(pid=" lastPid ") -> Del")
            return
        }
    }

    delClosed := CloseScriptByWindow(DEL_SCRIPT)
    kompletClosed := CloseScriptByWindow(KOMPLET_SCRIPT)
    Log("ToggleScripts | delClosed=" delClosed " | kompletClosed=" kompletClosed)

    if (delClosed > 0) {
        StartAndSaveState(KOMPLET_SCRIPT, "komplet")
        Log("Switch Del -> Komplet")
        return
    }

    if (kompletClosed > 0) {
        StartAndSaveState(DEL_SCRIPT, "del")
        Log("Switch Komplet -> Del")
        return
    }

    ; Když neběží nic, přepne podle posledního stavu (ať to není vždy Del).
    target := (lastMode = "del") ? KOMPLET_SCRIPT : DEL_SCRIPT
    targetMode := (target = DEL_SCRIPT) ? "del" : "komplet"
    StartAndSaveState(target, targetMode)
    Log("Switch by state | last=" lastMode " | target=" target)
}

StartAndSaveState(scriptPath, mode) {
    global AHK_EXE, STATE_FILE
    Sleep 350
    Run '"' AHK_EXE '" "' scriptPath '"', , , &newPid
    try FileDelete STATE_FILE
    FileAppend mode "|" newPid, STATE_FILE, "UTF-8"
}

ReadState(&mode, &pid) {
    global STATE_FILE
    mode := ""
    pid := 0
    if !FileExist(STATE_FILE)
        return
    raw := Trim(FileRead(STATE_FILE, "UTF-8"))
    parts := StrSplit(raw, "|")
    if (parts.Length >= 1)
        mode := parts[1]
    if (parts.Length >= 2)
        pid := parts[2] + 0
}

CloseScriptByWindow(scriptPath) {
    SplitPath scriptPath, &scriptName
    closed := 0

    ; 1) Pokus podle plné cesty v titulku.
    for hwnd in WinGetList(scriptPath " ahk_class AutoHotkey") {
        try {
            pid := WinGetPID("ahk_id " hwnd)
            ProcessClose pid
            closed++
        }
    }

    ; 2) Pokus podle názvu skriptu v titulku.
    for hwnd in WinGetList(scriptName " ahk_class AutoHotkey") {
        try {
            pid := WinGetPID("ahk_id " hwnd)
            ProcessClose pid
            closed++
        }
    }

    ; 3) Fallback: zkusit přes PID detekované WMI/titulkem.
    pids := GetScriptPids(scriptPath)
    if (pids.Length > 0) {
        ClosePids(pids)
        closed += pids.Length
    }

    return closed
}

GetScriptPids(scriptPath) {
    pids := []
    SplitPath scriptPath, &scriptName
    try {
        wmi := ComObjGet("winmgmts:\\\\.\\root\\cimv2")
        q := "SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name='AutoHotkey.exe' OR Name='AutoHotkey64.exe'"
        for p in wmi.ExecQuery(q) {
            cmd := p.CommandLine
            if !IsSet(cmd) || (cmd = "")
                continue
            if InStr(cmd, scriptPath) || InStr(cmd, '"' scriptName '"') || InStr(cmd, scriptName) {
                pids.Push(p.ProcessId)
            }
        }
    }

    for hwnd in WinGetList("ahk_class AutoHotkey") {
        title := WinGetTitle("ahk_id " hwnd)
        if InStr(title, scriptPath) || InStr(title, scriptName) {
            try {
                pid := WinGetPID("ahk_id " hwnd)
                if !HasPid(pids, pid)
                    pids.Push(pid)
            }
        }
    }

    return pids
}

HasPid(arr, needle) {
    for , one in arr {
        if (one = needle)
            return true
    }
    return false
}

ClosePids(pids) {
    for , pid in pids {
        try ProcessClose pid
    }
}

Log(msg) {
    global LOG_FILE, LOG_ENABLED
    if !LOG_ENABLED
        return
    ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    try FileAppend ts " | " msg "`n", LOG_FILE, "UTF-8"
}

EmptyWindowsRecycleBin() {
    ; Vysype standardní Windows Koš (všechny jednotky).
    ; SHERB_NOCONFIRMATION=0x1, SHERB_NOPROGRESSUI=0x2, SHERB_NOSOUND=0x4
    flags := 0x1 | 0x2 | 0x4
    try DllCall("Shell32\SHEmptyRecycleBinW", "Ptr", 0, "Ptr", 0, "UInt", flags, "Int")
}

CopyTestFilesIfMissing() {
    global SOURCE_FOLDER, SOURCE_FILES, TARGET_DIRS

    for , dir in TARGET_DIRS {
        if !DirExist(dir)
            continue

        for , oneFile in SOURCE_FILES {
            src := SOURCE_FOLDER oneFile
            dst := dir oneFile

            if !FileExist(src)
                continue

            if FileExist(dst)
                continue

            try FileCopy src, dst, false
        }
    }
}

ClearRecycleTargets() {
    global RECYCLE_DIRS_FULL_DELETE, RECYCLE_DIR_SINGLE_DELETE

    for , dir in RECYCLE_DIRS_FULL_DELETE {
        DeleteDirectoryContents(dir)
    }

    if DirExist(RECYCLE_DIR_SINGLE_DELETE) {
        try DirDelete RECYCLE_DIR_SINGLE_DELETE, true
    }
}

DeleteDirectoryContents(dirPath) {
    if !DirExist(dirPath)
        return

    Loop Files dirPath "*", "FD" {
        full := A_LoopFileFullPath
        try {
            if InStr(FileExist(full), "D")
                DirDelete full, true
            else
                FileDelete full
        }
    }
}

DeleteHardFolder(dirPath) {
    if !DirExist(dirPath)
        return
    try DirDelete dirPath, true
}

main()
