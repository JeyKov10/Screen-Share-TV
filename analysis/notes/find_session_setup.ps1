$dexDump = "C:\Users\riosv\AppData\Local\Android\Sdk\build-tools\36.0.0\dexdump.exe"
$extractDir = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_extract"

Write-Host "Searching for session setup & key generation across all extracted DEX files..."

$dexFiles = Get-ChildItem $extractDir *.dex

foreach ($f in $dexFiles) {
    Write-Host "`nScanning $($f.Name)..."
    $dumpFile = Join-Path $extractDir ($f.Name + ".txt")
    if (-not (Test-Path $dumpFile)) {
        & $dexDump -d $f.FullName > $dumpFile
    }

    $lines = [System.IO.File]::ReadAllLines($dumpFile)
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $l = $lines[$i]
        if ($l -match "RTPStreamerSetting|setStreamingConfig|SecurityConfig|masterKey|ssrc|SET_PARAMETER|HELLO|LGCast|ScreenMirroring") {
            if ($l -match "Class descriptor|Method name|invoke-|iget-|iput-|const-string") {
                Write-Host "  Line $i : $l"
            }
        }
    }
}
