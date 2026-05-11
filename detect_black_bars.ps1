# Detect videos with burned-in black bars and suggest safe FFmpeg crop values.

$ErrorActionPreference = 'Stop'

$pathsToScan = @(
    '\\QNAS1911\08 TV\01 Filmy',
    '\\QNAS1911\08 TV\02 Serialy',
    '\\QNAS1911\08 TV\03 Pohadky'
)

$outFile = 'D:\Vypis cernych filmovych okraju.txt'

$ffmpeg  = 'p:\Programy\zSkripty\FFmpeg\bin\ffmpeg.exe'
$ffprobe = 'p:\Programy\zSkripty\FFmpeg\bin\ffprobe.exe'

$videoExt = @('.mp4','.mkv','.avi','.mov','.wmv','.m4v','.ts','.m2ts','.mpg','.mpeg','.webm')

function Get-VideoDurationSec {
    param([string]$file)
    $dur = & $ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -- "$file" 2>$null
    if (-not $dur) { return $null }
    [double]::Parse($dur.Trim(), [System.Globalization.CultureInfo]::InvariantCulture)
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
        '-ss', $timeSec,
        '-i', $file,
        '-t', '3',
        '-vf', 'fps=2,cropdetect=24:16:0',
        '-an',
        '-sn',
        '-dn',
        '-f', 'null',
        '-'
    )

    $output = & $ffmpeg @args 2>&1
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

    $widthReduced = ($first.X -gt 0)
    $heightReduced = ($first.Y -gt 0)
    if (-not ($widthReduced -or $heightReduced)) { return $null }

    [pscustomobject]@{
        File = $file
        Duration = $duration
        SampleCount = $samples.Count
        StableCount = $stable.Count
        Crop = $first
        CropText = "crop=$($first.W):$($first.H):$($first.X):$($first.Y)"
        FfmpegCmd = "ffmpeg -i \"$file\" -vf \"$('crop=' + $first.W + ':' + $first.H + ':' + $first.X + ':' + $first.Y)\" -c:a copy OUTPUT.mkv"
    }
}

if (-not (Test-Path -LiteralPath $ffmpeg)) { throw "Nenalezen ffmpeg: $ffmpeg" }
if (-not (Test-Path -LiteralPath $ffprobe)) { throw "Nenalezen ffprobe: $ffprobe" }

$videos = foreach ($root in $pathsToScan) {
    if (Test-Path -LiteralPath $root) {
        Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $videoExt -contains $_.Extension.ToLowerInvariant() }
    }
}

$results = @()
$idx = 0
foreach ($v in $videos) {
    $idx++
    Write-Host "[$idx/$($videos.Count)] Analyzuji: $($v.FullName)"
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
) + ($pathsToScan | ForEach-Object { " - $_" }) + @('')

if ($results.Count -eq 0) {
    $content = $header + @('Nenalezeny žádné jednoznačně stabilní černé okraje.')
    $content | Set-Content -LiteralPath $outFile -Encoding UTF8
    Write-Host "Hotovo. Výstup: $outFile"
    exit 0
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
