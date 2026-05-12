# Detect videos with burned-in black bars and suggest safe FFmpeg crop values.

param(
    [string[]]$CustomPaths
)

$ErrorActionPreference = 'Stop'

# V PowerShell 7 nativni stderr muze vyvolat exception pri ErrorActionPreference=Stop.
# FFmpeg zapisuje bezne informacni vystup na stderr, proto to vypneme.
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$pathsToScan = @(
    '\\QNAS1911\08 TV\01 Filmy',
    '\\QNAS1911\08 TV\02 Seriály',
    '\\QNAS1911\08 TV\03 Pohádky'
)

if ($CustomPaths -and $CustomPaths.Count -gt 0) {
    if ($CustomPaths.Count -eq 1 -and $CustomPaths[0] -match ',') {
        $CustomPaths = $CustomPaths[0].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    $pathsToScan = $CustomPaths
}

function Resolve-ScanPath {
    param([string]$path)
    if (Test-Path -LiteralPath $path) { return $path }

    $fallbackMap = @{
        '\\QNAS1911\08 TV\02 Serialy' = '\\QNAS1911\08 TV\02 Seriály'
        '\\QNAS1911\08 TV\03 Pohadky' = '\\QNAS1911\08 TV\03 Pohádky'
        '\\QNAS1911\08 TV\02 Seriály' = '\\QNAS1911\08 TV\02 Serialy'
        '\\QNAS1911\08 TV\03 Pohádky' = '\\QNAS1911\08 TV\03 Pohadky'
    }

    if ($fallbackMap.ContainsKey($path)) {
        $alt = $fallbackMap[$path]
        if (Test-Path -LiteralPath $alt) { return $alt }
    }
    return $path
}

$pathsToScan = $pathsToScan | ForEach-Object { Resolve-ScanPath -path $_ } | Select-Object -Unique

$outFile = 'D:\Vypis cernych filmovych okraju.txt'

$ffmpeg  = 'p:\Programy\zSkripty\FFmpeg\bin\ffmpeg.exe'
$ffprobe = 'p:\Programy\zSkripty\FFmpeg\bin\ffprobe.exe'

$videoExt = @('.mp4','.mkv','.avi','.mov','.wmv','.m4v','.ts','.m2ts','.mpg','.mpeg','.webm')


function Show-DetailedProcedure {
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host "PODROBNY POSTUP" -ForegroundColor Cyan
    Write-Host "1) Skript projde NAS slozky s filmy/serialy/pohadkami." -ForegroundColor Gray
    Write-Host "2) U kazdeho videa zjisti delku (ffprobe)." -ForegroundColor Gray
    Write-Host "3) Z ruznych casti videa vezme vice vzorku casu." -ForegroundColor Gray
    Write-Host "4) V kazdem vzorku analyzuje vice snimku (cropdetect)." -ForegroundColor Gray
    Write-Host "5) Overi stabilitu cropu, aby odfiltroval tmave sceny." -ForegroundColor Gray
    Write-Host "6) Podezrele soubory zapise do vystupu vcetne FFmpeg crop prikazu." -ForegroundColor Gray
    Write-Host "7) Po dokonceni odesle zvuk do aktivni uzivatelske relace." -ForegroundColor Gray
    Write-Host ("=" * 60) -ForegroundColor DarkGray
}

function Get-ActiveUserSessionId {
    try {
        $lines = @(quser 2>$null)
    } catch {
        return $null
    }

    if ($lines.Count -lt 2) {
        return $null
    }

    foreach ($line in $lines | Select-Object -Skip 1) {
        $clean = $line.Trim()
        if ($clean -match '^\>?\s*\S+\s+\S+\s+(\d+)\s+Active\b') {
            return [int]$matches[1]
        }
        if ($clean -match '\s+(\d+)\s+Active\s+') {
            return [int]$matches[1]
        }
    }

    return $null
}

function Play-FinishSoundViaPsExec {
    param(
        [string]$PsExecPath = "P:\Programy\zSkripty\Ostatni\PsExec.exe",
        [string]$WavPath    = "P:\Programy\zSkripty\Ostatni\Success.wav"
    )

    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Zvukove upozorneni po dokonceni" -ForegroundColor Cyan

    if (-not (Test-Path -LiteralPath $PsExecPath -PathType Leaf)) {
        Write-Host "PsExec nenalezen: $PsExecPath" -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path -LiteralPath $WavPath -PathType Leaf)) {
        Write-Host "WAV soubor nenalezen: $WavPath" -ForegroundColor Yellow
        [console]::beep(1200,250)
        return
    }

    $sessionId = Get-ActiveUserSessionId

    if ($null -eq $sessionId) {
        Write-Host "Nepodarilo se zjistit aktivni uzivatelskou relaci." -ForegroundColor Yellow
        try { (New-Object Media.SoundPlayer $WavPath).PlaySync() } catch { [console]::beep(1200,250) }
        return
    }

    Write-Host "Aktivni uzivatelska relace: $sessionId" -ForegroundColor Gray
    Write-Host "Prehravam zvuk pres PsExec..." -ForegroundColor Gray

    $innerCommand = @"
try {
    `$player = New-Object System.Media.SoundPlayer
    `$player.SoundLocation = '$($WavPath.Replace("'", "''"))'
    `$player.Load()
    `$player.PlaySync()
} catch {
}
"@

    $bytes = [System.Text.Encoding]::Unicode.GetBytes($innerCommand)
    $encodedCommand = [Convert]::ToBase64String($bytes)

    try {
        & $PsExecPath `
            -accepteula `
            -i $sessionId `
            -d `
            powershell.exe `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -WindowStyle Hidden `
            -EncodedCommand $encodedCommand | Out-Null

        Write-Host "Zvuk byl odeslan do aktivni relace." -ForegroundColor Green
    } catch {
        Write-Host "Nepodarilo se prehrat zvuk pres PsExec:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        try { (New-Object Media.SoundPlayer $WavPath).PlaySync() } catch { [console]::beep(1200,250) }
    }
}

function Get-VideoDurationSec {
    param([string]$file)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $dur = & $ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -- "$file" 2>$null
    } finally {
        $ErrorActionPreference = $prevEap
    }
    if (-not $dur) { return $null }
    [double]::Parse($dur.Trim(), [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-VideoResolution {
    param([string]$file)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $raw = & $ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x -- "$file" 2>$null
    } finally {
        $ErrorActionPreference = $prevEap
    }
    if (-not $raw) { return $null }
    $parts = $raw.Trim().Split('x')
    if ($parts.Count -ne 2) { return $null }
    return [pscustomobject]@{ W = [int]$parts[0]; H = [int]$parts[1] }
}

function Get-SampleTimes {
    param([double]$duration)

    if (-not $duration -or $duration -lt 20) {
        return @(1,3,5)
    }

    $fractions = @(0.08,0.18,0.30,0.42,0.55,0.68,0.80,0.90)
    $times = foreach ($f in $fractions) {
        [Math]::Max(1, [Math]::Floor($duration * $f))
    }
    $times | Select-Object -Unique
}

function Parse-CropLine {
    param([string]$line)
    if ($line -match 'crop=(\d+):(\d+):(\d+):(\d+)') {
        return [pscustomobject]@{
            W = [int]$matches[1]
            H = [int]$matches[2]
            X = [int]$matches[3]
            Y = [int]$matches[4]
        }
    }
    return $null
}

function Get-CropdetectForTime {
    param([string]$file, [int]$timeSec)

    $args = @(
        '-hide_banner',
        '-loglevel', 'info',
        '-ss', $timeSec,
        '-i', $file,
        '-t', '3',
        # round=2 je citlivejsi na tenke (1-4 px) zapečene okraje.
        '-vf', 'fps=3,cropdetect=20:2:0',
        '-an',
        '-sn',
        '-dn',
        '-f', 'null',
        '-'
    )

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $ffmpeg @args 2>&1
    } finally {
        $ErrorActionPreference = $prevEap
    }
    $crops = @()
    foreach ($line in $output) {
        $parsed = Parse-CropLine -line $line
        if ($parsed) { $crops += $parsed }
    }

    if ($crops.Count -eq 0) { return $null }

    $group = $crops |
        Group-Object { "$($_.W):$($_.H):$($_.X):$($_.Y)" } |
        Sort-Object Count -Descending |
        Select-Object -First 1

    $p = ($group.Name -split ':')
    [pscustomobject]@{
        W = [int]$p[0]
        H = [int]$p[1]
        X = [int]$p[2]
        Y = [int]$p[3]
        Frames = [int]$group.Count
        TotalFrames = [int]$crops.Count
        Ratio = [double]$group.Count / [double]$crops.Count
    }
}

function Analyze-File {
    param([string]$file)

    $duration = Get-VideoDurationSec -file $file
    $sourceRes = Get-VideoResolution -file $file
    $times = Get-SampleTimes -duration $duration

    $samples = @()
    foreach ($t in $times) {
        $r = Get-CropdetectForTime -file $file -timeSec $t
        if ($r) {
            $samples += [pscustomobject]@{ T = $t; R = $r }
        }
    }

    if ($samples.Count -lt 3) { return $null }

    $stable = $samples | Where-Object { $_.R.Ratio -ge 0.60 }
    if ($stable.Count -lt [Math]::Ceiling($samples.Count * 0.6)) { return $null }

    $first = $stable[0].R
    $same = $stable | Where-Object {
        $_.R.W -eq $first.W -and
        $_.R.H -eq $first.H -and
        $_.R.X -eq $first.X -and
        $_.R.Y -eq $first.Y
    }

    if ($same.Count -lt [Math]::Ceiling($stable.Count * 0.7)) { return $null }

    $widthReduced = ($first.X -gt 0) -or ($sourceRes -and $first.W -lt $sourceRes.W)
    $heightReduced = ($first.Y -gt 0) -or ($sourceRes -and $first.H -lt $sourceRes.H)
    if (-not ($widthReduced -or $heightReduced)) { return $null }

    # Ignoruj velmi malé ořezy (typicky analogový šum/overscan), aby nebyly falešné poplachy.
    if ($sourceRes) {
        $removedW = [Math]::Max(0, $sourceRes.W - $first.W)
        $removedH = [Math]::Max(0, $sourceRes.H - $first.H)
        $minW = [Math]::Max(8, [Math]::Ceiling($sourceRes.W * 0.03))
        $minH = [Math]::Max(8, [Math]::Ceiling($sourceRes.H * 0.03))
        if ($removedW -lt $minW -and $removedH -lt $minH) { return $null }
    }

    [pscustomobject]@{
        File = $file
        Duration = $duration
        SampleCount = $samples.Count
        StableCount = $stable.Count
        Crop = $first
        CropText = "crop=$($first.W):$($first.H):$($first.X):$($first.Y)"
        FfmpegCmd = ('ffmpeg -i "{0}" -vf "crop={1}:{2}:{3}:{4}" -c:a copy OUTPUT.mkv' -f $file, $first.W, $first.H, $first.X, $first.Y)
    }
}

try {
Show-DetailedProcedure

if (-not (Test-Path -LiteralPath $ffmpeg)) { throw "Nenalezen ffmpeg: $ffmpeg" }
if (-not (Test-Path -LiteralPath $ffprobe)) { throw "Nenalezen ffprobe: $ffprobe" }

$rootStats = @()
$allFiles = @()
foreach ($root in $pathsToScan) {
    $exists = Test-Path -LiteralPath $root
    if (-not $exists) {
        $rootStats += [pscustomobject]@{ Root = $root; Exists = $false; FileCount = 0 }
        continue
    }

    $files = @(Get-ChildItem -LiteralPath $root -File -Recurse -Force -ErrorAction SilentlyContinue)
    $allFiles += $files
    $rootStats += [pscustomobject]@{ Root = $root; Exists = $true; FileCount = $files.Count }
}

$videos = $allFiles | Where-Object { $videoExt -contains $_.Extension.ToLowerInvariant() }
$totalFilesScanned = $allFiles.Count

Write-Host "Nalezeno souboru celkem: $totalFilesScanned" -ForegroundColor Cyan
Write-Host "Z toho videi k analyze: $($videos.Count)" -ForegroundColor Cyan
foreach ($s in $rootStats) {
    if ($s.Exists) {
        Write-Host ("  OK   {0} -> {1} souboru" -f $s.Root, $s.FileCount) -ForegroundColor DarkGray
    } else {
        Write-Warning ("CHYBI cesta: {0}" -f $s.Root)
    }
}

$results = @()
$idx = 0
$sw = [System.Diagnostics.Stopwatch]::StartNew()
foreach ($v in $videos) {
    $idx++
    $avg = if ($idx -gt 1) { $sw.Elapsed.TotalSeconds / ($idx - 1) } else { 0 }
    $remain = [Math]::Max(0, ($videos.Count - $idx) * $avg)
    $eta = [TimeSpan]::FromSeconds($remain).ToString("hh\\:mm\\:ss")
    Write-Host "[$idx/$($videos.Count)] ETA $eta | Analyzuji: $($v.FullName)"
    try {
        $res = Analyze-File -file $v.FullName
        if ($res) { $results += $res }
    } catch {
        Write-Warning "Chyba u souboru: $($v.FullName) :: $($_.Exception.Message)"
    }
}

$header = @(
    "Detekce zapečených černých okrajů"
    "Datum: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "Skenované složky:"
) + ($pathsToScan | ForEach-Object { " - $_" }) + @(
    "",
    "Srozumitelný popis pro laika:",
    "1) 'Nalezeno souboru celkem' = úplně všechny soubory ve složkách (video, titulky, obrázky...).",
    "2) 'Z toho videí k analýze' = jen video soubory podle podporovaných přípon.",
    "3) U každého videa se analyzuje více časů, aby se odlišila tmavá scéna od stálého černého okraje.",
    "4) Do výsledku jdou jen soubory se stabilním opakováním stejných okrajů.",
    "",
    "Statistika běhu:",
    " - Nalezeno souboru celkem: $totalFilesScanned",
    " - Z toho videí k analýze: $($videos.Count)",
    ""
)

if ($results.Count -eq 0) {
    $content = $header + @('Nenalezeny žádné jednoznačně stabilní černé okraje.')
    $content | Set-Content -LiteralPath $outFile -Encoding UTF8
    Write-Host "Hotovo. Výstup: $outFile"
    return
}

$body = foreach ($r in $results | Sort-Object File) {
    @(
        "Soubor: $($r.File)",
        "Doporučený crop: $($r.CropText)",
        "Ukázkový FFmpeg: $($r.FfmpegCmd)",
        "Vzorků celkem/stabilních: $($r.SampleCount)/$($r.StableCount)",
        ''
    )
}

($header + $body) | Set-Content -LiteralPath $outFile -Encoding UTF8
Write-Host "Hotovo. Nalezeno podezřelých souborů: $($results.Count). Výstup: $outFile"

} finally {
    Play-FinishSoundViaPsExec
}
