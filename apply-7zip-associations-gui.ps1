param(
    [string]$SevenZipFmPath = "C:\Programy\zSkripty\7-Zip\7zFM.exe",
    [int]$StartDelayMs = 1500,
    [int]$StepDelayMs = 600
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SevenZipFmPath)) {
    Write-Error "7zFM.exe not found: $SevenZipFmPath"
}

Add-Type -AssemblyName System.Windows.Forms

Write-Host "[INFO] Spoustim: $SevenZipFmPath"
$p = Start-Process -FilePath $SevenZipFmPath -PassThru

Start-Sleep -Milliseconds $StartDelayMs

# Aktivace okna 7-Zip (best-effort)
[System.Windows.Forms.SendKeys]::SendWait('% ')
Start-Sleep -Milliseconds 250

Write-Host "[INFO] Posilam Alt+T, O"
[System.Windows.Forms.SendKeys]::SendWait('%t')
Start-Sleep -Milliseconds $StepDelayMs
[System.Windows.Forms.SendKeys]::SendWait('o')
Start-Sleep -Milliseconds $StepDelayMs

Write-Host "[INFO] Potvrzuji dialog (2x Enter)"
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
Start-Sleep -Milliseconds $StepDelayMs
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
Start-Sleep -Milliseconds $StepDelayMs

Write-Host "[INFO] Navigace (3x TAB + Enter)"
[System.Windows.Forms.SendKeys]::SendWait('{TAB}')
Start-Sleep -Milliseconds $StepDelayMs
[System.Windows.Forms.SendKeys]::SendWait('{TAB}')
Start-Sleep -Milliseconds $StepDelayMs
[System.Windows.Forms.SendKeys]::SendWait('{TAB}')
Start-Sleep -Milliseconds $StepDelayMs
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
Start-Sleep -Milliseconds $StepDelayMs

Write-Host "[INFO] Zaviram 7-Zip (Alt+F4)"
[System.Windows.Forms.SendKeys]::SendWait('%{F4}')

Write-Host "[HOTOVO] GUI automatizace dokoncena."
Write-Host "[POZN] Pokud se ikony nesjednoti hned, restartujte Explorer nebo PC."
