#Requires AutoHotkey v2.0
#SingleInstance Force

SetTitleMatchMode(2)
SendMode("Event")
SetKeyDelay(80, 80)
DetectHiddenWindows True

; ==========================================================
; 01 ZACATEK - VERZE PODLE PUVODNIHO FUNKCNIHO FIREFOX POSTUPU
; ==========================================================
; Poradi:
;   1) spusti se VPN, pocka 5 sekund a posle se Alt+F4 jen na VPN okno
;   2) Firefox pres GUI zmeni slozku stahovani na E:\A\2
;   3) Firefox se zavre
;   4) otevre se anonymni Firefox
;   5) spusti se Tor Browser
;   6) spusti se ostatni programy
;   7) spusti se Del.ahk a cilene se ukonci Komplet.ahk
;
; Dulezite:
;   - Neni tu zadne hromadne CloseOtherAhkScripts().
;   - Firefox cast je ponechana podle puvodniho nahraneho souboru.
; ==========================================================

DeepL         := "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\DeepL.lnk"
Titul         := "P:\Programy\Subtitle Edit\SubtitleEdit.exe"
VPN           := "C:\Program Files (x86)\hide.me VPN\Hide.exe"
TOR           := "E:\Programy\Tor Browser\Tor Browser.lnk"
DelScript     := "P:\Programy\zSkripty\AHK\Já\Del.ahk"
KompletScript := "P:\Programy\zSkripty\AHK\Já\Komplet.ahk"
TcDeleteCmd   := "em_ahk_delete"

TargetDir := "E:\A\2"
LogFile   := A_ScriptDir "\01_zacatek_log.txt"

; ==========================================================
; TICHE FUNKCE - BEZ LOGU A BEZ HLASEK
; ==========================================================

Log(msg) {
    ; tichy rezim - nic nezapisuje
}

Step(msg) {
    ; tichy rezim - bez TrayTip hlaseni
}

; ==========================================================
; ZAKLADNI FUNKCE
; ==========================================================

TryRun(cmd) {
    Log("Spoustim: " cmd)
    try {
        Run(cmd)
        return true
    } catch as e {
        Log("CHYBA spusteni: " e.Message)
        return false
    }
}

RunAhkScript(scriptPath, args := "") {
    if !FileExist(scriptPath) {
        Log("AHK soubor neexistuje: " scriptPath)
        return false
    }

    cmd := '"' A_AhkPath '" "' scriptPath '"'

    if (args != "")
        cmd .= " " args

    return TryRun(cmd)
}

SetTcDeleteToDel() {
    global TcDeleteCmd
    tcUsercmdIni := GetTcUsercmdIniPath()
    if (tcUsercmdIni = "")
        return

    try IniWrite A_AhkPath, tcUsercmdIni, TcDeleteCmd, "cmd"
    try IniWrite '"P:\Programy\zSkripty\AHK\Já\Del.ahk" /tcbutton %UL', tcUsercmdIni, TcDeleteCmd, "param"
    try IniWrite "AHK Delete", tcUsercmdIni, TcDeleteCmd, "menu"

    ; Pojistka: over a pripadne jednou zopakuj zapis.
    Sleep 200
    if !IsTcDeleteMappedToDel(tcUsercmdIni, TcDeleteCmd) {
        try IniWrite A_AhkPath, tcUsercmdIni, TcDeleteCmd, "cmd"
        try IniWrite '"P:\Programy\zSkripty\AHK\Já\Del.ahk" /tcbutton %UL', tcUsercmdIni, TcDeleteCmd, "param"
        try IniWrite "AHK Delete", tcUsercmdIni, TcDeleteCmd, "menu"
        Sleep 200
    }
}

IsTcDeleteMappedToDel(tcUsercmdIni, section) {
    try p := IniRead(tcUsercmdIni, section, "param", "")
    catch {
        return false
    }

    return InStr(StrLower(p), "del.ahk") > 0
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

TryProcessClose(procName, waitTotalSec := 8) {
    try {
        endTime := A_TickCount + (waitTotalSec * 1000)

        Loop {
            pid := ProcessExist(procName)
            if !pid
                return true

            try ProcessClose(pid)
            try ProcessWaitClose(pid, 1)

            if (A_TickCount >= endTime)
                break

            Sleep 200
        }

        return !ProcessExist(procName)
    } catch {
        return false
    }
}

WaitProcessClosed(procName, waitTotalSec := 4) {
    try {
        endTime := A_TickCount + (waitTotalSec * 1000)

        while ProcessExist(procName) && A_TickCount < endTime
            Sleep 100

        return !ProcessExist(procName)
    } catch {
        return false
    }
}

ActivateAndMaximize(winTitle, waitSec := 15) {
    try {
        hwnd := WinWait(winTitle, , waitSec)
        if !hwnd
            return 0

        WinActivate("ahk_id " hwnd)

        if !WinWaitActive("ahk_id " hwnd, , 5)
            return 0

        Sleep 300
        WinMaximize("ahk_id " hwnd)
        Sleep 500

        return hwnd
    } catch {
        return 0
    }
}

TryActivateWindow(winTitle, waitSec := 10) {
    try {
        hwnd := WinWait(winTitle, , waitSec)
        if !hwnd
            return 0

        WinActivate("ahk_id " hwnd)

        if !WinWaitActive("ahk_id " hwnd, , waitSec)
            return 0

        return hwnd
    } catch {
        return 0
    }
}

SafeSend(keys) {
    try {
        Send(keys)
        return true
    } catch {
        return false
    }
}

TrySend(keys) {
    return SafeSend(keys)
}

SafeSendText(text) {
    try {
        SendText(text)
        return true
    } catch {
        return false
    }
}

TrySendText(text) {
    return SafeSendText(text)
}

GetProcessCommandLine(pid) {
    try {
        wmi := ComObjGet("winmgmts:")
        query := "Select CommandLine from Win32_Process where ProcessId=" pid

        for proc in wmi.ExecQuery(query)
            return proc.CommandLine
    } catch {
    }

    return ""
}

CloseAhkScriptByPath(scriptPath, timeoutSec := 5) {
    DetectHiddenWindows True

    targetLower := StrLower(scriptPath)
    scriptNameLower := StrLower(RegExReplace(scriptPath, "^.*\\", ""))
    closedPids := []

    for hwnd in WinGetList("ahk_class AutoHotkey") {
        try pid := WinGetPID("ahk_id " hwnd)
        catch {
            continue
        }

        cmdLine := GetProcessCommandLine(pid)

        if (cmdLine = "")
            continue

        cmdLower := StrLower(cmdLine)

        ; Nejdriv presna cela cesta, potom pojistka podle nazvu souboru.
        ; To resi pripady, kdy AHK ve WMI nevrati cestu presne ve stejnem tvaru.
        if InStr(cmdLower, targetLower) || InStr(cmdLower, scriptNameLower) {
            closedPids.Push(pid)
            try WinClose("ahk_id " hwnd)
        }
    }

    for pid in closedPids {
        endTime := A_TickCount + timeoutSec * 1000

        while ProcessExist(pid) && A_TickCount < endTime
            Sleep 100

        if ProcessExist(pid)
            try ProcessClose(pid)
    }
}

CloseKompletAhk() {
    global KompletScript

    ; Komplet.ahk cilene vypnout co nejspolehliveji.
    ; Nepouziva se zadne hromadne CloseOtherAhkScripts().
    CloseAhkScriptByPath(KompletScript, 5)
}

; ==========================================================
; FIREFOX - NASTAVENI SLOZKY PRO STAHOVANI PRES GUI
; Ponechano podle puvodniho funkcniho souboru.
; ==========================================================

ConfigureFirefoxDownloadDir() {
    global TargetDir

    Step("Firefox - nastaveni slozky stahovani")

    ; Rychle zavrit pripadny stary Firefox, aby se zmena slozky nedelala do stareho okna.
    TryProcessClose("firefox.exe", 6)
    Sleep 700

    if !TryRun('firefox.exe "about:preferences#general"')
        return false

    if !WinWait("ahk_exe firefox.exe", , 20)
        return false

    if !TryActivateWindow("ahk_exe firefox.exe", 10)
        return false

    try WinMaximize("ahk_exe firefox.exe")

    Sleep 2500

    TrySend("^f")
    Sleep 400

    TrySend("^a")
    Sleep 150

    TrySendText("stah")
    Sleep 1200

    TrySend("{Tab}")
    Sleep 300

    TrySend("{Tab}")
    Sleep 300

    TrySend("{Space}")
    Sleep 1000

    folderHwnd := WinWait("Vybrat složku", , 10)

    if folderHwnd {
        try WinActivate("ahk_id " folderHwnd)
        try WinWaitActive("ahk_id " folderHwnd, , 5)

        Sleep 500

        ; klik do pole Složka:
        Sleep 200

        ; zapsat cestu do spodniho pole
        TrySendText(TargetDir)
        Sleep 300

        ; potvrdit tlacitkem Vybrat slozku
        TrySend("{Tab}")
        Sleep 200

        TrySend("{Enter}")
        Sleep 1200
    }

    TryActivateWindow("ahk_exe firefox.exe", 5)
    Sleep 300

    TrySend("!{F4}")

    ; Necekat dlouho. Cas mezi zavrenim normalniho Firefoxu a otevrenim anonymniho
    ; je zkraceny zhruba na polovinu.
    if !WaitProcessClosed("firefox.exe", 2)
        TryProcessClose("firefox.exe", 1)

    Sleep 100

    return true
}

; ==========================================================
; VPN
; ==========================================================

StartVpnAndHideWindow() {
    global VPN

    Step("VPN - spusteni, cekani 5 sekund, Alt+F4")

    vpnPid := 0

    try {
        Log("Spoustim VPN: " VPN)
        Run('"' VPN '"', "", "", &vpnPid)
    } catch as e {
        Log("CHYBA spusteni VPN: " e.Message)
        vpnPid := 0
    }

    Sleep 5000

    vpnHwnd := 0

    if vpnPid {
        try vpnHwnd := WinWait("ahk_pid " vpnPid, , 10)
    }

    if !vpnHwnd {
        try vpnHwnd := WinWait("ahk_exe Hide.exe", , 15)
    }

    if vpnHwnd {
        try {
            if (WinGetMinMax("ahk_id " vpnHwnd) = -1)
                WinRestore("ahk_id " vpnHwnd)

            WinActivate("ahk_id " vpnHwnd)
            WinWaitActive("ahk_id " vpnHwnd, , 5)

            Sleep 500
            Log("VPN okno nalezeno, posilam Alt+F4")
            Send("!{F4}")
            Sleep 1000
        } catch as e {
            Log("CHYBA pri Alt+F4 VPN: " e.Message)
        }
    } else {
        Log("VPN okno nenalezeno")
    }
}

; ==========================================================
; HLAVNI CAST
; ==========================================================

; 1) VPN - nejdrive spustit, pockat 5 sekund a schovat Alt+F4
StartVpnAndHideWindow()

; 2) Firefox slozka -> zavrit Firefox
ConfigureFirefoxDownloadDir()

; 3) Otevrit anonymni Firefox
Step("Firefox - anonymni okno")
TryRun('firefox.exe -private-window')
firefoxPrivateHwnd := ActivateAndMaximize("ahk_exe firefox.exe", 20)
if firefoxPrivateHwnd
    Sleep 2000

; 4) TOR
Step("Tor Browser")
TryRun('"' TOR '"')

torHwnd := WinWait("Prohlížeč Tor ahk_class MozillaWindowClass", , 25)

if !torHwnd
    torHwnd := WinWait("Tor Browser ahk_class MozillaWindowClass", , 10)

if torHwnd {
    Sleep 2000
    WinActivate("ahk_id " torHwnd)
    WinWaitActive("ahk_id " torHwnd, , 5)
    Sleep 500
    WinMaximize("ahk_id " torHwnd)
}

; 5) DEEPL
; Jen spustit pres odkaz. NEMAXIMALIZOVAT podle ahk_exe DeepL.exe,
; protoze DeepL ma i skryte .NET-BroadcastEventWindow a to se pak muze chytit misto hlavniho okna.
Step("DeepL")
TryRun('"' DeepL '"')
Sleep 2000

; 6) SUBTITLE EDIT
Step("Subtitle Edit")
TryRun('"' Titul '"')
WinWait("ahk_exe SubtitleEdit.exe", , 10)

; 7) Del.ahk zapnout a Komplet.ahk cilene vypnout
Step("Zapinam Del.ahk a vypinam Komplet.ahk")
RunAhkScript(DelScript)
Sleep 500
CloseKompletAhk()
SetTcDeleteToDel()

; 8) UKONCENI PROGRAMU Z BEZNEHO REZIMU - stejne omezeny seznam jako v puvodnim souboru
Step("Ukonceni programu z bezneho rezimu")
TryProcessClose("picpick.exe")
TryProcessClose("stpass.exe")
TryProcessClose("TeamViewer.exe")

Sleep 500
ExitApp()
