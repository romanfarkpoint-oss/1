#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; Media - Playlist.ahk
; Verze baliku asociaci: v37
; ============================================================
; Ucel:
;   Po dvojkliku na video nebo hudbu:
;     1) zjisti slozku vybraneho souboru,
;     2) podle typu nacte vsechna videa nebo vsechnu hudbu ve stejne slozce,
;     3) seradi je prirozene podobne jako Windows,
;     4) vytvori XSPF playlist z cele slozky ve spravnem poradi,
;     5) otevre playlist ve VLC,
;     6) pokud vybrany soubor neni prvni, prepne VLC pres lokalni HTTP
;        ovladani na konkretni polozku playlistu.
;
; Vysledek:
;   Playlist ve VLC obsahuje celou slozku daneho typu:
;     klik na film  -> playlist filmu
;     klik na hudbu -> playlist hudby
;   Prehravani zacne na souboru, na ktery bylo kliknuto.
;   Sipka/dalsi soubor pokracuje dal, predchozi soubor jde zpet.
;
; Logovani:
;   Vypnuto - skript nikam nezapisuje provozni log.
; ============================================================

SCRIPT_NAME := "Media - Playlist"
SCRIPT_VERSION := "v37"
PLAYLIST_DIR := ""
INI_FILE := ""
HTTP_TIMEOUT_MS := 25000

ENABLE_VLC_FULLSCREEN_OSD := false
VLC_OSD_HTTP_PORT := 0
VLC_OSD_HTTP_PASSWORD := ""
VLC_OSD_GUI := 0
VLC_OSD_LEFT_TEXT := 0
VLC_OSD_RIGHT_TEXT := 0
VLC_OSD_LAST_LEFT_TEXT := ""
VLC_OSD_LAST_RIGHT_TEXT := ""
VLC_OSD_BOTTOM_MARGIN := 6
VLC_OSD_LEFT_MARGIN := 22
VLC_OSD_RIGHT_MARGIN := 35
VLC_OSD_TEXT_GAP := 80
VLC_OSD_MAX_WIDTH := 900
VLC_OSD_LAYOUT_VERSION := "rohy_v3_dpi"
VLC_OSD_NO_VLC_TICKS := 0

VIDEO_EXTENSIONS := Map(
    "264", true,
    "265", true,
    "3g2", true,
    "3gp", true,
    "3gp2", true,
    "3gpp", true,
    "amv", true,
    "asf", true,
    "avi", true,
    "av1", true,
    "avc", true,
    "avs", true,
    "bik", true,
    "braw", true,
    "bsf", true,
    "camrec", true,
    "cine", true,
    "dash", true,
    "dav", true,
    "divx", true,
    "drc", true,
    "dv", true,
    "dvr-ms", true,
    "evo", true,
    "f4p", true,
    "f4v", true,
    "flc", true,
    "fli", true,
    "flv", true,
    "g64", true,
    "gvi", true,
    "gxf", true,
    "h261", true,
    "h263", true,
    "h264", true,
    "h265", true,
    "hevc", true,
    "ifo", true,
    "imx", true,
    "ismv", true,
    "ivf", true,
    "m1v", true,
    "m2p", true,
    "m2t", true,
    "m2ts", true,
    "m2v", true,
    "m4e", true,
    "m4v", true,
    "mj2", true,
    "mjpeg", true,
    "mjpg", true,
    "mks", true,
    "mkv", true,
    "mng", true,
    "mod", true,
    "mov", true,
    "movie", true,
    "mp2v", true,
    "mp4", true,
    "mp4v", true,
    "mpe", true,
    "mpeg", true,
    "mpeg1", true,
    "mpeg2", true,
    "mpeg4", true,
    "mpg", true,
    "mpg2", true,
    "mpv", true,
    "mpv2", true,
    "mts", true,
    "mve", true,
    "mxf", true,
    "mxg", true,
    "nsv", true,
    "nut", true,
    "nuv", true,
    "ogm", true,
    "ogv", true,
    "ogx", true,
    "pss", true,
    "qt", true,
    "r3d", true,
    "rec", true,
    "rm", true,
    "rmvb", true,
    "roq", true,
    "rv", true,
    "sfd", true,
    "smk", true,
    "ssif", true,
    "swf", true,
    "tod", true,
    "tp", true,
    "trp", true,
    "ts", true,
    "tts", true,
    "vfw", true,
    "vid", true,
    "vob", true,
    "vro", true,
    "webm", true,
    "wm", true,
    "wmv", true,
    "wtv", true,
    "xesc", true,
    "xvid", true,
    "y4m", true
)

AUDIO_EXTENSIONS := Map(
    "2sf", true,
    "3ga", true,
    "4mp", true,
    "669", true,
    "8svx", true,
    "aa", true,
    "aac", true,
    "aax", true,
    "ac3", true,
    "act", true,
    "adpcm", true,
    "adt", true,
    "adts", true,
    "afc", true,
    "aif", true,
    "aifc", true,
    "aiff", true,
    "alac", true,
    "amr", true,
    "ape", true,
    "apl", true,
    "au", true,
    "awb", true,
    "caf", true,
    "cda", true,
    "cdda", true,
    "dff", true,
    "dsf", true,
    "dsm", true,
    "dts", true,
    "dtshd", true,
    "dvf", true,
    "f32", true,
    "f64", true,
    "fla", true,
    "flac", true,
    "gsm", true,
    "hcom", true,
    "iff", true,
    "it", true,
    "kar", true,
    "la", true,
    "m3u", true,
    "m3u8", true,
    "m4a", true,
    "m4b", true,
    "m4p", true,
    "m4r", true,
    "mid", true,
    "midi", true,
    "mka", true,
    "mlp", true,
    "mmf", true,
    "mo3", true,
    "mod", true,
    "mp1", true,
    "mp2", true,
    "mp3", true,
    "mpa", true,
    "mpc", true,
    "mpp", true,
    "msv", true,
    "oga", true,
    "ogg", true,
    "oma", true,
    "opus", true,
    "pls", true,
    "qcp", true,
    "ra", true,
    "ram", true,
    "rmi", true,
    "s3m", true,
    "sds", true,
    "shn", true,
    "snd", true,
    "spc", true,
    "spx", true,
    "tak", true,
    "tta", true,
    "voc", true,
    "vox", true,
    "vqf", true,
    "w64", true,
    "wav", true,
    "wave", true,
    "wax", true,
    "wma", true,
    "wv", true,
    "wve", true,
    "xa", true,
    "xm", true
)

Main()

Main() {
    global PLAYLIST_DIR

    try DirCreate(PLAYLIST_DIR)

    input := GetInputFileAndPlayer()
    player := input.Player
    selectedFile := input.File

    Log("============================================================")
    Log("Start skriptu")
    Log("Rezim: " player)

    if (selectedFile = "") {
        Log("Nebyl predan zadny soubor.")
        ExitApp(1)
    }

    if !FileExist(selectedFile) {
        Log("Soubor neexistuje: " selectedFile)
        MsgBox("Soubor neexistuje:`n`n" selectedFile, SCRIPT_NAME, "Iconx")
        ExitApp(2)
    }

    selectedFile := GetFullPath(selectedFile)

    if (player = "winamp") {
        RunWinampPlaylistMode(selectedFile)
        return
    }

    RunVlcPlaylistMode(selectedFile)
}

RunVlcPlaylistMode(selectedFile) {
    global HTTP_TIMEOUT_MS

    SplitPath(selectedFile, &selectedName, &selectedDir, &selectedExt)

    if (selectedDir = "") {
        Log("Nepodarilo se zjistit slozku souboru: " selectedFile)
        MsgBox("Nepodarilo se zjistit slozku vybraneho souboru.", SCRIPT_NAME, "Iconx")
        ExitApp(3)
    }

    if !(IsVideoExtension(selectedExt) || IsAudioExtension(selectedExt)) {
        Log("Vybrany soubor nema podporovanou video ani audio priponu, spoustim pouze tento soubor: " selectedFile)
        StartVlcWithSingleFile(selectedFile)
        ExitApp(0)
    }

    ; v32: VLC playlist bere spolecne video i hudbu ze stejne slozky.
    ; Duvod: kdyz jsou ve slozce filmy i hudba, dalsi/predchozi nema
    ; preskakovat soubory jen proto, ze maji jiny media typ.
    mediaType := "all"
    mediaLabel := "media"

    Log("Vybrany soubor: " selectedFile)
    Log("Slozka: " selectedDir)
    Log("Typ playlistu: spolecne video + audio")

    files := GetMediaFilesFromFolder(selectedDir, mediaType)

    if (files.Length = 0) {
        Log("Ve slozce nebyly nalezeny zadne " mediaLabel " soubory.")
        StartVlcWithSingleFile(selectedFile)
        ExitApp(0)
    }

    SortPathsNaturally(files)

    startIndex := FindFileIndex(files, selectedFile)

    if (startIndex = 0) {
        Log("Vybrany soubor nebyl nalezen v nactenem seznamu, spoustim pouze tento soubor.")
        StartVlcWithSingleFile(selectedFile)
        ExitApp(0)
    }

    Log("Pocet souboru ve slozce pro vybrany typ: " files.Length)
    Log("Pozice vybraneho souboru v puvodni slozce: " startIndex)

    ; v37: Playlist zustava v puvodnim prirozenem poradi slozky.
    ; Kliknuty soubor se po startu vybere pres HTTP rozhrani VLC, aby seznam
    ; zustal 1,2,3,4,5 a prehravani zacalo treba na 3. polozce.
    playlistPath := CreateXspfPlaylist(files)

    if (playlistPath = "") {
        Log("Nepodarilo se vytvorit playlist, spoustim pouze tento soubor.")
        StartVlcWithSingleFile(selectedFile)
        ExitApp(0)
    }

    httpPort := Random(43000, 62000)
    httpPassword := GenerateHttpPassword()

    StartVlcWithPlaylist(playlistPath, selectedDir, httpPort, httpPassword)

    if (startIndex > 1) {
        if SwitchVlcToSelectedFile(httpPort, httpPassword, selectedFile, startIndex, files.Length, HTTP_TIMEOUT_MS) {
            Log("VLC prepnut na vybrany soubor pri zachovanem poradi playlistu.")
        } else {
            Log("VAROVANI: Nepodarilo se prepnout VLC na vybrany soubor v casovem limitu.")
        }
    }

    Log("VLC spusteno s playlistem v puvodnim poradi slozky.")
    ExitApp(0)
}


GetInputFileAndPlayer() {
    player := "vlc"
    file := ""

    for arg in A_Args {
        a := StrLower(Trim(arg))

        if (a = "--winamp" || a = "/winamp" || a = "-winamp" || a = "--player=winamp") {
            player := "winamp"
            continue
        }

        if (a = "--vlc" || a = "/vlc" || a = "-vlc" || a = "--player=vlc") {
            player := "vlc"
            continue
        }

        if (file = "") {
            file := arg
        }
    }

    if (file = "") {
        selected := FileSelect(
            1,
            "",
            "Vyber video nebo hudebni soubor",
            "Media soubory (*.mkv; *.mp4; *.avi; *.mov; *.wmv; *.flac; *.mp3; *.m4a; *.wav; *.wma; *.ogg)"
        )
        file := selected
    }

    return { Player: player, File: file }
}

GetMediaFilesFromFolder(folderPath, mediaType) {
    files := []

    Loop Files, folderPath "\*.*", "F" {
        currentPath := A_LoopFileFullPath
        SplitPath(currentPath, &fileName, &dir, &ext)

        if (mediaType = "all" && (IsVideoExtension(ext) || IsAudioExtension(ext))) {
            files.Push(GetFullPath(currentPath))
        } else if (mediaType = "video" && IsVideoExtension(ext)) {
            files.Push(GetFullPath(currentPath))
        } else if (mediaType = "audio" && IsAudioExtension(ext)) {
            files.Push(GetFullPath(currentPath))
        }
    }

    return files
}

IsVideoExtension(ext) {
    global VIDEO_EXTENSIONS

    ext := StrLower(Trim(ext, " .`t`r`n"))

    if (ext = "") {
        return false
    }

    return VIDEO_EXTENSIONS.Has(ext)
}

IsAudioExtension(ext) {
    global AUDIO_EXTENSIONS

    ext := StrLower(Trim(ext, " .`t`r`n"))

    if (ext = "") {
        return false
    }

    return AUDIO_EXTENSIONS.Has(ext)
}

FindFileIndex(files, selectedFile) {
    selectedFileLower := StrLower(GetFullPath(selectedFile))

    for index, filePath in files {
        if (StrLower(GetFullPath(filePath)) = selectedFileLower) {
            return index
        }
    }

    return 0
}


EnsurePlaylistDir() {
    dirs := []

    localAppData := EnvGet("LOCALAPPDATA")
    if (localAppData != "")
        dirs.Push(localAppData "\Media_Playlist")

    envTemp := EnvGet("TEMP")
    if (envTemp != "")
        dirs.Push(envTemp)

    if (A_Temp != "")
        dirs.Push(A_Temp)

    dirs.Push(A_ScriptDir)

    for dir in UniqueArray(dirs) {
        if (dir = "")
            continue

        try {
            DirCreate(dir)
            if DirExist(dir) {
                testFile := dir "\_write_test_" A_TickCount "_" Random(100000, 999999) ".tmp"
                try {
                    FileAppend("test", testFile, "UTF-8-RAW")
                    if FileExist(testFile)
                        FileDelete(testFile)
                    return dir
                } catch as e {
                    Log("Nelze zapisovat do slozky pro playlist: " dir " | " e.Message)
                }
            }
        } catch as e {
            Log("Nelze pouzit slozku pro playlist: " dir " | " e.Message)
        }
    }

    return A_ScriptDir
}

SafeWriteTextFile(filePath, content) {
    SplitPath(filePath, , &dir)

    if (dir != "") {
        try DirCreate(dir)
    }

    try {
        if FileExist(filePath)
            FileDelete(filePath)
    } catch {
        ; kdyz soubor neexistuje nebo je zamceny, pokracujeme na zapis,
        ; vlastni zapis pripadne zahlasi presnou chybu.
    }

    try {
        FileAppend(content, filePath, "UTF-8-RAW")
        if !FileExist(filePath)
            throw Error("Soubor po zapisu neexistuje.")
        return true
    } catch as e {
        throw e
    }
}


ContainsAnyExtension(files, extensions) {
    wanted := Map()
    for ext in extensions {
        wanted[StrLower(Trim(ext, " .`t`r`n"))] := true
    }

    for filePath in files {
        SplitPath(filePath, , , &ext)
        ext := StrLower(Trim(ext, " .`t`r`n"))
        if (ext != "" && wanted.Has(ext)) {
            return true
        }
    }

    return false
}

IsAviLikeFile(filePath) {
    SplitPath(filePath, , , &ext)
    ext := StrLower(Trim(ext, " .`t`r`n"))
    return (ext = "avi" || ext = "divx")
}

CreateXspfPlaylist(files) {
    playlistDir := EnsurePlaylistDir()

    randomPart := Random(100000, 999999)
    playlistPath := playlistDir "\VLC_Playlist_" A_Now "_" randomPart ".xspf"

    content := "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`r`n"
    content .= "<playlist xmlns=`"http://xspf.org/ns/0/`" xmlns:vlc=`"http://www.videolan.org/vlc/playlist/ns/0/`" version=`"1`">`r`n"
    content .= "  <title>VLC - Playlist</title>`r`n"
    content .= "  <trackList>`r`n"

    for index, filePath in files {
        id := index - 1
        SplitPath(filePath, &fileName)
        uri := FilePathToUriUtf8(filePath)

        content .= "    <track>`r`n"
        content .= "      <location>" XmlEscape(uri) "</location>`r`n"
        content .= "      <title>" XmlEscape(fileName) "</title>`r`n"
        content .= "      <extension application=`"http://www.videolan.org/vlc/playlist/0`">`r`n"
        content .= "        <vlc:id>" id "</vlc:id>`r`n"
        if (IsAviLikeFile(filePath))
            content .= "        <vlc:option>avi-index=2</vlc:option>`r`n"
        content .= "      </extension>`r`n"
        content .= "    </track>`r`n"
    }

    content .= "  </trackList>`r`n"
    content .= "  <extension application=`"http://www.videolan.org/vlc/playlist/0`">`r`n"

    for index, filePath in files {
        id := index - 1
        content .= "    <vlc:item tid=`"" id "`"/>`r`n"
    }

    content .= "  </extension>`r`n"
    content .= "</playlist>`r`n"

    try {
        SafeWriteTextFile(playlistPath, content)
        Log("XSPF playlist vytvoren: " playlistPath)
        return playlistPath
    } catch as e {
        Log("Chyba pri vytvareni XSPF playlistu: " e.Message)
        return ""
    }
}


EnsureVlcAviIndexNeverFix() {
    ; v34: Nastavi VLC tak, aby se neptalo na opravu AVI indexu.
    ; 2 = Never fix podle VLC napovedy: 0 Ask, 1 Always fix, 2 Never fix, 3 Fix when necessary.
    appData := EnvGet("APPDATA")
    if (appData = "")
        return

    vlcDir := appData "\vlc"
    vlcrc := vlcDir "\vlcrc"

    try DirCreate(vlcDir)

    content := ""
    if FileExist(vlcrc) {
        try {
            content := FileRead(vlcrc, "UTF-8")
        } catch {
            try {
                content := FileRead(vlcrc)
            } catch {
                content := ""
            }
        }
    }

    if (content = "") {
        content := "avi-index=2`r`n"
    } else if RegExMatch(content, "m)^#?avi-index=.*$") {
        content := RegExReplace(content, "m)^#?avi-index=.*$", "avi-index=2")
    } else {
        content .= "`r`navi-index=2`r`n"
    }

    try {
        SafeWriteTextFile(vlcrc, content)
        Log("VLC vlcrc nastaveno: avi-index=2 (Never fix): " vlcrc)
    } catch as e {
        Log("VAROVANI: Nepodarilo se nastavit vlcrc avi-index=2: " e.Message)
    }
}

StartVlcWithPlaylist(playlistPath, workingDir, httpPort, httpPassword) {
    vlcPath := GetVlcPath()

    if (vlcPath = "") {
        MsgBox("Nepodarilo se najit vlc.exe.", "VLC - Playlist", "Iconx")
        Log("Nepodarilo se najit vlc.exe.")
        ExitApp(10)
    }

    EnsureVlcAviIndexNeverFix()

    commandLine := Quote(vlcPath)
        . " --no-one-instance"
        . " --started-from-file"
        . " --playlist-autostart"
        . " --no-qt-error-dialogs"
        . " --no-interact"
        . " --quiet"
        . " --avi-index=2"
        . " --no-video-title-show"
        . " --no-qt-privacy-ask"
        . " --extraintf=http"
        . " --http-host=127.0.0.1"
        . " --http-port=" httpPort
        . " --http-password=" httpPassword
        . " " Quote(playlistPath)

    Log("Spoustim VLC s playlistem cele slozky:")
    Log(commandLine)

    try {
        Run(commandLine, workingDir)
    } catch as e {
        Log("Chyba pri spusteni VLC: " e.Message)
        MsgBox("Nepodarilo se spustit VLC:`n`n" e.Message, "VLC - Playlist", "Iconx")
        ExitApp(11)
    }
}

StartVlcWithSingleFile(filePath) {
    SplitPath(filePath, &fileName, &workingDir)

    vlcPath := GetVlcPath()

    if (vlcPath = "") {
        MsgBox("Nepodarilo se najit vlc.exe.", "VLC - Playlist", "Iconx")
        Log("Nepodarilo se najit vlc.exe.")
        ExitApp(20)
    }

    EnsureVlcAviIndexNeverFix()

    SplitPath(filePath, , , &singleExt)
    singleExt := StrLower(Trim(singleExt, " .`t`r`n"))
    extraDemux := (singleExt = "avi" || singleExt = "divx") ? " --demux=avformat" : ""

    commandLine := Quote(vlcPath) " --started-from-file --no-qt-error-dialogs --no-interact --quiet --avi-index=2" extraDemux " " Quote(filePath)

    Log("Spoustim VLC pouze s jednim souborem:")
    Log(commandLine)

    try {
        Run(commandLine, workingDir)
    } catch as e {
        Log("Chyba pri spusteni VLC s jednim souborem: " e.Message)
        MsgBox("Nepodarilo se spustit VLC:`n`n" e.Message, "VLC - Playlist", "Iconx")
        ExitApp(21)
    }
}

SwitchVlcToSelectedFile(httpPort, httpPassword, selectedFile, selectedIndex, expectedItemCount, timeoutMs) {
    deadline := A_TickCount + timeoutMs
    selectedIdFallback := selectedIndex - 1
    selectedId := ""
    lastPlayCommandTick := 0

    while (A_TickCount < deadline) {
        playlistXml := HttpGet("http://127.0.0.1:" httpPort "/requests/playlist.xml", httpPassword)

        if (playlistXml != "") {
            leafCount := GetVlcPlaylistLeafCount(playlistXml)
            foundId := FindVlcPlaylistIdByFile(playlistXml, selectedFile)

            if (foundId != "") {
                selectedId := foundId
                Log("ID vybraneho souboru ve VLC playlistu: " selectedId)
            } else if (selectedId = "" && leafCount >= expectedItemCount) {
                selectedId := selectedIdFallback
                Log("ID vybraneho souboru se nepodarilo najit podle URI ani nazvu, zkousim fallback ID: " selectedId)
            }

            if (selectedId != "") {
                if ((A_TickCount - lastPlayCommandTick) >= 700) {
                    HttpGet("http://127.0.0.1:" httpPort "/requests/status.xml?command=pl_play&id=" selectedId, httpPassword)
                    lastPlayCommandTick := A_TickCount
                }

                if IsVlcPlayingSelectedFile(httpPort, httpPassword, selectedId, selectedFile) {
                    Sleep(250)

                    if IsVlcPlayingSelectedFile(httpPort, httpPassword, selectedId, selectedFile) {
                        return true
                    }
                }
            }
        }

        Sleep(250)
    }

    return false
}

IsVlcPlayingSelectedFile(httpPort, httpPassword, selectedId, selectedFile) {
    statusXml := HttpGet("http://127.0.0.1:" httpPort "/requests/status.xml", httpPassword)

    if (statusXml != "") {
        currentId := GetXmlElementText(statusXml, "currentplid")

        if (currentId != "" && selectedId != "" && currentId = selectedId) {
            return true
        }

        statusFileName := GetVlcStatusFileName(statusXml)

        if (statusFileName != "") {
            SplitPath(selectedFile, &targetName)

            if (StrLower(statusFileName) = StrLower(targetName)) {
                return true
            }
        }
    }

    playlistXml := HttpGet("http://127.0.0.1:" httpPort "/requests/playlist.xml", httpPassword)

    if (playlistXml != "") {
        currentId := GetCurrentVlcPlaylistId(playlistXml)

        if (currentId != "" && selectedId != "" && currentId = selectedId) {
            return true
        }
    }

    return false
}

GetVlcStatusFileName(statusXml) {
    try {
        dom := ComObject("MSXML2.DOMDocument.6.0")
        dom.async := false
        dom.setProperty("SelectionLanguage", "XPath")

        if !dom.loadXML(statusXml) {
            return ""
        }

        nodes := dom.selectNodes("//info[@name='filename']")

        for node in nodes {
            value := Trim(node.text)

            if (value != "") {
                return value
            }
        }
    } catch {
        return ""
    }

    return ""
}

GetVlcPlaylistLeafCount(playlistXml) {
    try {
        dom := ComObject("MSXML2.DOMDocument.6.0")
        dom.async := false
        dom.setProperty("SelectionLanguage", "XPath")

        if !dom.loadXML(playlistXml) {
            return 0
        }

        nodes := dom.selectNodes("//leaf")
        return nodes.length
    } catch {
        return 0
    }
}

GetCurrentVlcPlaylistId(playlistXml) {
    try {
        dom := ComObject("MSXML2.DOMDocument.6.0")
        dom.async := false
        dom.setProperty("SelectionLanguage", "XPath")

        if !dom.loadXML(playlistXml) {
            return ""
        }

        nodes := dom.selectNodes("//leaf")

        for node in nodes {
            id := node.getAttribute("id")
            current := node.getAttribute("current")

            if (id != "" && current != "") {
                return id
            }
        }
    } catch {
        return ""
    }

    return ""
}

GetXmlElementText(xml, elementName) {
    try {
        pattern := "is)<" elementName ">(.*?)</" elementName ">"

        if RegExMatch(xml, pattern, &m) {
            return Trim(m[1])
        }
    } catch {
        return ""
    }

    return ""
}

FindVlcPlaylistIdByFile(xml, selectedFile) {
    targetUri := StrLower(FilePathToUriUtf8(selectedFile))
    SplitPath(selectedFile, &targetName)
    targetName := StrLower(targetName)

    try {
        dom := ComObject("MSXML2.DOMDocument.6.0")
        dom.async := false
        dom.setProperty("SelectionLanguage", "XPath")

        if !dom.loadXML(xml) {
            return ""
        }

        nodes := dom.selectNodes("//leaf")

        for node in nodes {
            uri := node.getAttribute("uri")
            id := node.getAttribute("id")

            if (id = "") {
                continue
            }

            if (uri != "" && StrLower(uri) = targetUri) {
                return id
            }
        }

        for node in nodes {
            name := node.getAttribute("name")
            id := node.getAttribute("id")

            if (id != "" && name != "" && StrLower(name) = targetName) {
                return id
            }
        }
    } catch as e {
        Log("Chyba pri parsovani VLC playlist XML: " e.Message)
    }

    return ""
}

HttpGet(url, password) {
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", url, false)
        req.SetTimeouts(1000, 1000, 1000, 1000)
        req.SetRequestHeader("Authorization", "Basic " Base64EncodeUtf8(":" password))
        req.Send()

        if (req.Status >= 200 && req.Status < 300) {
            return req.ResponseText
        }

        Log("HTTP odpoved " req.Status " pro URL: " url)
        return ""
    } catch {
        return ""
    }
}

Base64EncodeUtf8(text) {
    byteCount := StrPut(text, "UTF-8") - 1

    if (byteCount <= 0) {
        return ""
    }

    inputBuffer := Buffer(byteCount, 0)
    StrPut(text, inputBuffer, "UTF-8")

    flags := 0x40000001
    chars := 0

    if !DllCall("Crypt32.dll\CryptBinaryToStringW", "Ptr", inputBuffer, "UInt", byteCount, "UInt", flags, "Ptr", 0, "UInt*", &chars) {
        return ""
    }

    outputBuffer := Buffer(chars * 2, 0)

    if !DllCall("Crypt32.dll\CryptBinaryToStringW", "Ptr", inputBuffer, "UInt", byteCount, "UInt", flags, "Ptr", outputBuffer, "UInt*", &chars) {
        return ""
    }

    return StrGet(outputBuffer, "UTF-16")
}


IsVlcBlockingDialogOpen() {
    ; Vraci true, kdyz VLC zobrazi modalni/chybovy dialog.
    ; Pak AHK prestane delat OSD/HTTP dohled a necha rozhodnuti na uzivateli.
    try hwnds := WinGetList("ahk_exe vlc.exe")
    catch {
        return false
    }

    for hwnd in hwnds {
        try {
            if !WinExist("ahk_id " hwnd)
                continue

            title := ""
            className := ""

            try title := WinGetTitle("ahk_id " hwnd)
            catch title := ""

            try className := WinGetClass("ahk_id " hwnd)
            catch className := ""

            lowerTitle := StrLower(title)
            lowerClass := StrLower(className)

            if (className = "#32770") {
                Log("VLC dialog detekovan podle tridy #32770: " title)
                return true
            }

            if (InStr(lowerTitle, "avi") && (InStr(lowerTitle, "index") || InStr(lowerTitle, "rejst") || InStr(lowerTitle, "posko") || InStr(lowerTitle, "poško") || InStr(lowerTitle, "chyb") || InStr(lowerTitle, "broken") || InStr(lowerTitle, "repair") || InStr(lowerTitle, "missing") || InStr(lowerTitle, "damaged"))) {
                Log("VLC dialog detekovan podle titulku: " title " / " className)
                return true
            }

            if ((InStr(lowerTitle, "vlc") || InStr(lowerTitle, "media player")) && (InStr(lowerTitle, "error") || InStr(lowerTitle, "chyba") || InStr(lowerTitle, "warning") || InStr(lowerTitle, "varovani") || InStr(lowerTitle, "varování"))) {
                Log("VLC chybove okno detekovano podle titulku: " title " / " className)
                return true
            }
        } catch {
            continue
        }
    }

    return false
}

StartVlcPlaylistOsd(httpPort, httpPassword) {
    global ENABLE_VLC_FULLSCREEN_OSD
    global VLC_OSD_HTTP_PORT
    global VLC_OSD_HTTP_PASSWORD

    if !ENABLE_VLC_FULLSCREEN_OSD {
        ExitApp(0)
    }

    VLC_OSD_HTTP_PORT := httpPort
    VLC_OSD_HTTP_PASSWORD := httpPassword

    Persistent(true)
    try OnExit(VlcPlaylistOsdOnExit)
    SetTimer(UpdateVlcPlaylistOsd, 500)
    UpdateVlcPlaylistOsd()
}

UpdateVlcPlaylistOsd(*) {
    global VLC_OSD_HTTP_PORT
    global VLC_OSD_HTTP_PASSWORD
    global VLC_OSD_NO_VLC_TICKS

    if IsVlcBlockingDialogOpen() {
        Log("Detekovano modalni/chybove okno VLC behem OSD dohledu. Vypinam OSD a ukoncuji AHK skript.")
        HideVlcPlaylistOsd()
        ExitApp(0)
    }

    if !ProcessExist("vlc.exe") {
        VLC_OSD_NO_VLC_TICKS += 1
        HideVlcPlaylistOsd()

        if (VLC_OSD_NO_VLC_TICKS >= 6) {
            ExitApp(0)
        }
        return
    }

    VLC_OSD_NO_VLC_TICKS := 0

    timeState := GetVlcTimeStateForOsd(VLC_OSD_HTTP_PORT, VLC_OSD_HTTP_PASSWORD)

    if !timeState["ok"] {
        HideVlcPlaylistOsd()
        return
    }

    ; Dulezite: OSD se smi zobrazit jen pri skutecnem fullscreen rezimu VLC.
    ; Neurcuje se podle velikosti okna, protoze maximalizovane okno se driv mylne bralo jako fullscreen.
    if !timeState["fullscreen"] {
        HideVlcPlaylistOsd()
        return
    }

    if (timeState["length"] <= 0) {
        HideVlcPlaylistOsd()
        return
    }

    vlcWindow := FindVlcWindowForOsd()
    if !vlcWindow["ok"] {
        HideVlcPlaylistOsd()
        return
    }

    elapsed := timeState["time"]
    remaining := timeState["length"] - timeState["time"]

    if (remaining < 0)
        remaining := 0

    ShowVlcPlaylistOsd("Uplynulo: " FormatVlcSecondsForOsd(elapsed), "Zbývá: " FormatVlcSecondsForOsd(remaining), vlcWindow)
}

FindVlcWindowForOsd() {
    result := Map("ok", false, "left", 0, "top", 0, "right", A_ScreenWidth, "bottom", A_ScreenHeight, "w", A_ScreenWidth, "h", A_ScreenHeight)
    bestArea := -1

    try hwnds := WinGetList("ahk_exe vlc.exe")
    catch {
        return result
    }

    for hwnd in hwnds {
        try {
            if !WinExist("ahk_id " hwnd)
                continue

            state := WinGetMinMax("ahk_id " hwnd)
            if (state = -1)
                continue

            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (w <= 0 || h <= 0)
                continue

            area := w * h
            if (area <= bestArea)
                continue

            mon := GetBestMonitorForRect(x, y, w, h)
            if !mon["ok"]
                continue

            bestArea := area
            result["ok"] := true
            result["left"] := mon["left"]
            result["top"] := mon["top"]
            result["right"] := mon["right"]
            result["bottom"] := mon["bottom"]
            result["w"] := mon["w"]
            result["h"] := mon["h"]
        } catch {
        }
    }

    return result
}

GetBestMonitorForRect(x, y, w, h) {
    best := Map("ok", false, "left", 0, "top", 0, "right", 0, "bottom", 0, "w", 0, "h", 0)
    bestArea := -1

    try count := MonitorGetCount()
    catch {
        return best
    }

    Loop count {
        try MonitorGet(A_Index, &left, &top, &right, &bottom)
        catch
            continue

        ix1 := Max(x, left)
        iy1 := Max(y, top)
        ix2 := Min(x + w, right)
        iy2 := Min(y + h, bottom)
        area := Max(0, ix2 - ix1) * Max(0, iy2 - iy1)

        if (area > bestArea) {
            bestArea := area
            best["ok"] := true
            best["left"] := left
            best["top"] := top
            best["right"] := right
            best["bottom"] := bottom
            best["w"] := right - left
            best["h"] := bottom - top
        }
    }

    return best
}

GetVlcTimeStateForOsd(httpPort, httpPassword) {
    result := Map("ok", false, "time", 0, "length", 0, "fullscreen", false)

    if (httpPort <= 0)
        return result

    statusXml := HttpGet("http://127.0.0.1:" httpPort "/requests/status.xml", httpPassword)

    if (statusXml = "")
        return result

    timeValue := 0
    lengthValue := 0
    fullscreenValue := false

    if RegExMatch(statusXml, "is)<time>\s*(-?\d+)\s*</time>", &mTime)
        timeValue := Integer(mTime[1])

    if RegExMatch(statusXml, "is)<length>\s*(-?\d+)\s*</length>", &mLength)
        lengthValue := Integer(mLength[1])

    if RegExMatch(statusXml, "is)<fullscreen>\s*(.*?)\s*</fullscreen>", &mFullscreen) {
        fullText := StrLower(Trim(mFullscreen[1]))
        fullscreenValue := (fullText = "1" || fullText = "true")
    }

    if (timeValue < 0)
        timeValue := 0

    if (lengthValue < 0)
        lengthValue := 0

    if (timeValue > lengthValue && lengthValue > 0)
        timeValue := lengthValue

    result["ok"] := true
    result["time"] := timeValue
    result["length"] := lengthValue
    result["fullscreen"] := fullscreenValue
    return result
}

FormatVlcSecondsForOsd(seconds) {
    seconds := Integer(seconds)

    if (seconds < 0)
        seconds := 0

    h := seconds // 3600
    m := Mod(seconds // 60, 60)
    s := Mod(seconds, 60)

    if (h > 0)
        return Format("{}:{:02}:{:02}", h, m, s)

    return Format("{:02}:{:02}", m, s)
}

CreateVlcPlaylistOsdIfNeeded() {
    global VLC_OSD_GUI
    global VLC_OSD_LEFT_TEXT
    global VLC_OSD_RIGHT_TEXT

    if IsObject(VLC_OSD_GUI)
        return

    ; Dulezite pro Windows meritko / DPI: souradnice OSD musi odpovidat souradnicim monitoru.
    try DllCall("User32.dll\SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

    VLC_OSD_GUI := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
    VLC_OSD_GUI.BackColor := "111111"
    VLC_OSD_GUI.MarginX := 0
    VLC_OSD_GUI.MarginY := 0
    VLC_OSD_GUI.SetFont("s18 Bold cFFFFFF", "Segoe UI")

    VLC_OSD_LEFT_TEXT := VLC_OSD_GUI.AddText("x18 y8 w300 h36 Left cFFFFFF BackgroundTrans", "")
    VLC_OSD_RIGHT_TEXT := VLC_OSD_GUI.AddText("x398 y8 w430 h36 Right cFFFFFF BackgroundTrans", "")
}

ShowVlcPlaylistOsd(leftText, rightText, vlcWindow) {
    global VLC_OSD_GUI
    global VLC_OSD_LEFT_TEXT
    global VLC_OSD_RIGHT_TEXT
    global VLC_OSD_LAST_LEFT_TEXT
    global VLC_OSD_LAST_RIGHT_TEXT
    global VLC_OSD_BOTTOM_MARGIN
    global VLC_OSD_LEFT_MARGIN
    global VLC_OSD_RIGHT_MARGIN
    global VLC_OSD_TEXT_GAP
    global VLC_OSD_MAX_WIDTH

    CreateVlcPlaylistOsdIfNeeded()

    if (VLC_OSD_LAST_LEFT_TEXT != leftText) {
        VLC_OSD_LEFT_TEXT.Text := leftText
        VLC_OSD_LAST_LEFT_TEXT := leftText
    }

    if (VLC_OSD_LAST_RIGHT_TEXT != rightText) {
        VLC_OSD_RIGHT_TEXT.Text := rightText
        VLC_OSD_LAST_RIGHT_TEXT := rightText
    }

    try {
        barH := 58
        minMargin := 0
        leftMargin := VLC_OSD_LEFT_MARGIN
        rightMargin := VLC_OSD_RIGHT_MARGIN

        if (leftMargin < 0)
            leftMargin := 0

        if (rightMargin < 0)
            rightMargin := 0

        ; OSD pruh je pres celou sirku aktivniho VLC monitoru, aby:
        ;   - Uplynulo bylo v levem dolnim rohu,
        ;   - Zbyva bylo u praveho dolniho rohu.
        barX := vlcWindow["left"] + minMargin
        barW := vlcWindow["w"] - (minMargin * 2)

        ; Pojistka pro DPI / meritko Windows.
        ; Nektere kombinace VLC + AutoHotkey vraci sirku monitoru ve fyzickych pixelech,
        ; zatimco GUI prvky se pocitaji ve skalovanych souradnicich. Bez teto pojistky
        ; muze byt pravy text mimo viditelnou cast obrazovky.
        if (A_ScreenWidth > 0 && barW > A_ScreenWidth)
            barW := A_ScreenWidth

        if (barW < 300)
            barW := 300

        barY := vlcWindow["bottom"] - barH - VLC_OSD_BOTTOM_MARGIN

        leftW := 380
        rightW := 330
        rightX := barW - rightMargin - rightW

        if (rightX < leftMargin + leftW + 20) {
            availableW := barW - leftMargin - rightMargin - 20
            if (availableW < 320)
                availableW := 320

            leftW := Floor(availableW / 2)
            rightW := leftW
            rightX := barW - rightMargin - rightW
        }

        VLC_OSD_LEFT_TEXT.Move(leftMargin, 8, leftW, 36)
        VLC_OSD_RIGHT_TEXT.Move(rightX, 8, rightW, 36)

        VLC_OSD_GUI.Show("NoActivate x" barX " y" barY " w" barW " h" barH)
        WinSetTransparent(95, "ahk_id " VLC_OSD_GUI.Hwnd)
        WinSetAlwaysOnTop(true, "ahk_id " VLC_OSD_GUI.Hwnd)
    } catch {
        HideVlcPlaylistOsd()
    }
}

HideVlcPlaylistOsd() {
    global VLC_OSD_GUI
    global VLC_OSD_LAST_LEFT_TEXT
    global VLC_OSD_LAST_RIGHT_TEXT

    if IsObject(VLC_OSD_GUI) {
        try VLC_OSD_GUI.Hide()
    }

    VLC_OSD_LAST_LEFT_TEXT := ""
    VLC_OSD_LAST_RIGHT_TEXT := ""
}

VlcPlaylistOsdOnExit(*) {
    HideVlcPlaylistOsd()
}

GenerateHttpPassword() {
    return "vlc" Random(10000000, 99999999)
}


RunWinampPlaylistMode(selectedFile) {
    SplitPath(selectedFile, &selectedName, &selectedDir, &selectedExt)

    if (selectedDir = "") {
        MsgBox("Nepodarilo se zjistit slozku vybraneho souboru.", SCRIPT_NAME, "Iconx")
        ExitApp(30)
    }

    if !IsAudioExtension(selectedExt) {
        StartWinampWithSingleFile(selectedFile)
        ExitApp(0)
    }

    files := GetMediaFilesFromFolder(selectedDir, "audio")

    if (files.Length = 0) {
        StartWinampWithSingleFile(selectedFile)
        ExitApp(0)
    }

    SortPathsNaturally(files)
    startIndex := FindFileIndex(files, selectedFile)

    if (startIndex = 0) {
        StartWinampWithSingleFile(selectedFile)
        ExitApp(0)
    }

    playlist := CreateM3U8PlaylistForWinamp(files, selectedDir)
    StartWinampWithPlaylist(playlist, startIndex)
    ExitApp(0)
}

RotateFilesForPlaylist(files, startIndex) {
    ordered := []

    Loop files.Length {
        idx := startIndex + A_Index - 1
        if (idx > files.Length)
            idx -= files.Length
        ordered.Push(files[idx])
    }

    return ordered
}

RotateFilesForWinamp(files, startIndex) {
    return RotateFilesForPlaylist(files, startIndex)
}

CreateM3U8PlaylistForWinamp(files, selectedDir) {
    playlistDir := EnsurePlaylistDir()

    randomPart := Random(100000, 999999)
    playlist := playlistDir "\Winamp_Playlist_" A_Now "_" A_TickCount "_" randomPart ".m3u8"

    content := "#EXTM3U`r`n"
    for filePath in files {
        content .= filePath "`r`n"
    }

    try {
        SafeWriteTextFile(playlist, content)
        Log("Winamp M3U8 playlist vytvoren: " playlist)
        return playlist
    } catch as e {
        ; Zalozni pokus primo v TEMP bez podslozky.
        try {
            fallbackRoot := EnvGet("TEMP")
            if (fallbackRoot = "")
                fallbackRoot := A_Temp
            fallback := fallbackRoot "\Winamp_Playlist_" A_Now "_" A_TickCount "_" randomPart ".m3u8"
            SafeWriteTextFile(fallback, content)
            Log("Winamp M3U8 playlist vytvoren zalozne: " fallback)
            return fallback
        } catch as e2 {
            MsgBox("Nepodarilo se vytvorit Winamp playlist:`n`n" playlist "`n`n" e.Message "`n`nZalozni pokus:`n" e2.Message, SCRIPT_NAME, "Iconx")
            ExitApp(34)
        }
    }
}

SanitizeFileNameForWinamp(value) {
    value := RegExReplace(value, "^[A-Za-z]:\\", "")
    value := StrReplace(value, "\", "_")
    value := StrReplace(value, ":", "_")
    for ch in ["<", ">", Chr(34), "/", "|", "?", "*"]
        value := StrReplace(value, ch, "_")
    value := RegExReplace(value, "\s+", " ")
    value := Trim(value, " ._`t`r`n")
    if (value = "")
        value := "playlist"
    return SubStr(value, 1, 120)
}

GetWinampExe() {
    candidates := [
        "P:\Programy\Winamp\winamp.exe",
        A_ProgramFiles "\Winamp\winamp.exe",
        EnvGet("ProgramFiles(x86)") "\Winamp\winamp.exe"
    ]

    for exe in candidates {
        if (exe != "" && FileExist(exe))
            return exe
    }

    return "P:\Programy\Winamp\winamp.exe"
}

StartWinampWithPlaylist(playlist, startIndex := 1) {
    winamp := GetWinampExe()
    try Run(Quote(winamp) " " Quote(playlist))
    catch as e {
        MsgBox("Nepodarilo se spustit Winamp:`n`n" e.Message, SCRIPT_NAME, "Iconx")
        ExitApp(31)
    }

    if (startIndex > 1) {
        SelectWinampPlaylistItem(startIndex)
    }
}

SelectWinampPlaylistItem(startIndex) {
    targetPos := startIndex - 1
    deadline := A_TickCount + 10000
    hwnd := 0

    while (A_TickCount < deadline) {
        try hwnd := WinExist("ahk_class Winamp v1.x")
        catch hwnd := 0

        if (hwnd) {
            try {
                ; WM_WA_IPC = 0x400, IPC_SETPLAYLISTPOS = 121, IPC_STARTPLAY = 102.
                SendMessage(0x400, targetPos, 121, , "ahk_id " hwnd)
                Sleep(150)
                SendMessage(0x400, 0, 102, , "ahk_id " hwnd)
                Log("Winamp prepnut na pozici playlistu: " startIndex)
                return true
            } catch as e {
                Log("VAROVANI: Nepodarilo se prepnout Winamp playlist: " e.Message)
            }
        }

        Sleep(250)
    }

    return false
}

StartWinampWithSingleFile(filePath) {
    winamp := GetWinampExe()
    try Run(Quote(winamp) " " Quote(filePath))
    catch as e {
        MsgBox("Nepodarilo se spustit Winamp:`n`n" e.Message, SCRIPT_NAME, "Iconx")
        ExitApp(32)
    }
}

GetVlcPath() {
    global INI_FILE

    ; 1) Nejdřív zkusím INI uložený vedle VLC.
    for _, iniPath in GetIniCandidatePaths() {
        savedPath := ""

        try {
            savedPath := IniRead(iniPath, "Nastaveni", "VLC", "")
        }

        if (savedPath != "" && FileExist(savedPath)) {
            INI_FILE := iniPath
            Log("Cesta k VLC nactena z INI: " iniPath)

            preferredIni := SaveVlcPathToIni(savedPath)

            if (preferredIni != "" && preferredIni != iniPath) {
                Log("INI presunuto do preferovaneho umisteni: " preferredIni)
                TryDeleteOldIni(iniPath, preferredIni)
            }

            return savedPath
        }
    }

    ; 2) Když INI neexistuje, najdu VLC v obvyklých cestách.
    for _, candidate in GetVlcCandidatePaths() {
        if FileExist(candidate) {
            SaveVlcPathToIni(candidate)
            return candidate
        }
    }

    ; 3) Poslední možnost: ruční výběr vlc.exe.
    chosen := FileSelect(1, "", "Najdi vlc.exe", "VLC (*.exe)")

    if (chosen != "" && FileExist(chosen)) {
        SaveVlcPathToIni(chosen)
        return chosen
    }

    return ""
}

GetVlcCandidatePaths() {
    candidates := []

    ; Tvoje obvyklé umístění.
    candidates.Push("P:\Programy\VideoLAN\VLC\vlc.exe")
    candidates.Push("P:\Programy\VLC\vlc.exe")
    candidates.Push("C:\Programy\VideoLAN\VLC\vlc.exe")
    candidates.Push("C:\Programy\VLC\vlc.exe")

    ; Běžná instalace VLC.
    pf := EnvGet("ProgramFiles")
    pf86 := EnvGet("ProgramFiles(x86)")

    if (pf != "") {
        candidates.Push(pf "\VideoLAN\VLC\vlc.exe")
    }

    if (pf86 != "") {
        candidates.Push(pf86 "\VideoLAN\VLC\vlc.exe")
    }

    return candidates
}

GetIniCandidatePaths() {
    global SCRIPT_NAME

    candidates := []

    ; Nové preferované umístění: vedle vlc.exe.
    for _, vlcPath in GetVlcCandidatePaths() {
        SplitPath(vlcPath, , &vlcDir)
        if (vlcDir != "") {
            candidates.Push(vlcDir "\" SCRIPT_NAME ".ini")
        }
    }

    ; Záložní umístění bez nutnosti práv správce.
    candidates.Push(GetFallbackIniPath())

    ; Staré umístění vedle AHK skriptu kvůli migraci.
    candidates.Push(A_ScriptDir "\" SCRIPT_NAME ".ini")

    return UniqueArray(candidates)
}

SaveVlcPathToIni(vlcPath) {
    global INI_FILE

    iniPath := GetPreferredIniPathForVlc(vlcPath)

    try {
        SplitPath(iniPath, , &iniDir)
        if (iniDir != "") {
            DirCreate(iniDir)
        }

        IniWrite(vlcPath, iniPath, "Nastaveni", "VLC")
        INI_FILE := iniPath
        Log("Cesta k VLC ulozena do INI: " iniPath)
        return iniPath
    } catch as e {
        Log("VAROVANI: Nepodarilo se zapsat INI do preferovaneho umisteni: " iniPath " | " e.Message)
    }

    iniPath := GetFallbackIniPath()

    try {
        SplitPath(iniPath, , &iniDir)
        if (iniDir != "") {
            DirCreate(iniDir)
        }

        IniWrite(vlcPath, iniPath, "Nastaveni", "VLC")
        INI_FILE := iniPath
        Log("Cesta k VLC ulozena do zalozniho INI: " iniPath)
        return iniPath
    } catch as e {
        Log("VAROVANI: Nepodarilo se zapsat ani zalozni INI: " iniPath " | " e.Message)
    }

    return ""
}

GetPreferredIniPathForVlc(vlcPath) {
    global SCRIPT_NAME

    SplitPath(vlcPath, , &vlcDir)

    if (vlcDir != "" && CanWriteToFolder(vlcDir)) {
        return vlcDir "\" SCRIPT_NAME ".ini"
    }

    return GetFallbackIniPath()
}

GetFallbackIniPath() {
    global SCRIPT_NAME

    appData := EnvGet("APPDATA")

    if (appData != "") {
        return appData "\Roman\" SCRIPT_NAME "\" SCRIPT_NAME ".ini"
    }

    return A_Temp "\" SCRIPT_NAME "\" SCRIPT_NAME ".ini"
}

CanWriteToFolder(folderPath) {
    if (folderPath = "" || !DirExist(folderPath)) {
        return false
    }

    testPath := folderPath "\.~" A_ScriptName "_write_test_" A_TickCount "_" Random(1000, 9999) ".tmp"

    try {
        FileAppend("test", testPath, "UTF-8")
        FileDelete(testPath)
        return true
    } catch {
        try FileDelete(testPath)
        return false
    }
}

TryDeleteOldIni(oldIniPath, newIniPath) {
    if (oldIniPath = "" || newIniPath = "") {
        return
    }

    if (StrLower(oldIniPath) = StrLower(newIniPath)) {
        return
    }

    if !FileExist(oldIniPath) {
        return
    }

    try {
        FileDelete(oldIniPath)
        Log("Stare INI odstraneno: " oldIniPath)
    } catch as e {
        Log("Stare INI se nepodarilo odstranit: " oldIniPath " | " e.Message)
    }
}

UniqueArray(arr) {
    result := []
    seen := Map()

    for _, item in arr {
        key := StrLower(item)

        if !seen.Has(key) {
            seen[key] := true
            result.Push(item)
        }
    }

    return result
}
SortPathsNaturally(arr) {
    n := arr.Length

    if (n < 2) {
        return
    }

    Loop (n - 1) {
        swapped := false
        limit := n - A_Index
        i := 1

        while (i <= limit) {
            if (ComparePathNamesNaturally(arr[i], arr[i + 1]) > 0) {
                tmp := arr[i]
                arr[i] := arr[i + 1]
                arr[i + 1] := tmp
                swapped := true
            }

            i += 1
        }

        if !swapped {
            break
        }
    }
}

ComparePathNamesNaturally(pathA, pathB) {
    SplitPath(pathA, &nameA)
    SplitPath(pathB, &nameB)

    return DllCall("Shlwapi.dll\StrCmpLogicalW", "Str", nameA, "Str", nameB, "Int")
}

FilePathToUriUtf8(path) {
    path := GetFullPath(path)

    if (SubStr(path, 1, 2) = "\\") {
        unc := SubStr(path, 3)
        unc := StrReplace(unc, "\", "/")
        return "file://" PercentEncodeUriPath(unc)
    }

    if RegExMatch(path, "i)^[A-Z]:\\") {
        drive := SubStr(path, 1, 2)
        rest := SubStr(path, 4)
        rest := StrReplace(rest, "\", "/")
        if (rest != "") {
            return "file:///" drive "/" PercentEncodeUriPath(rest)
        }
        return "file:///" drive "/"
    }

    path := StrReplace(path, "\", "/")
    return "file:///" PercentEncodeUriPath(path)
}

PercentEncodeUriPath(text) {
    allowed := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~/!$&'()*+,;=:@"
    result := ""

    Loop Parse, text {
        ch := A_LoopField

        if InStr(allowed, ch, true) {
            result .= ch
            continue
        }

        byteCount := StrPut(ch, "UTF-8") - 1
        buf := Buffer(byteCount, 0)
        StrPut(ch, buf, "UTF-8")

        Loop byteCount {
            b := NumGet(buf, A_Index - 1, "UChar")
            result .= "%" Format("{:02X}", b)
        }
    }

    return result
}

XmlEscape(text) {
    text := StrReplace(text, "&", "&amp;")
    text := StrReplace(text, "<", "&lt;")
    text := StrReplace(text, ">", "&gt;")
    text := StrReplace(text, Chr(34), "&quot;")
    text := StrReplace(text, Chr(39), "&apos;")
    return text
}

GetFullPath(path) {
    try {
        cc := DllCall("Kernel32.dll\GetFullPathNameW", "Str", path, "UInt", 0, "Ptr", 0, "Ptr", 0, "UInt")

        if (cc = 0) {
            return path
        }

        buf := Buffer(cc * 2, 0)
        DllCall("Kernel32.dll\GetFullPathNameW", "Str", path, "UInt", cc, "Ptr", buf, "Ptr", 0, "UInt")

        return StrGet(buf, "UTF-16")
    } catch {
        return path
    }
}

Quote(text) {
    return Chr(34) text Chr(34)
}

Log(text) {
    ; Logovani je zamerne vypnute.
    ; Funkce zustava jen proto, aby nebylo nutne menit zbytek skriptu.
}
