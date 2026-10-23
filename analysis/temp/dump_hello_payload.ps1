$dump15 = "C:\Users\riosv\Desktop\Screen Share TV\analysis\rea_raw\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

Write-Host "=== SEARCHING FOR HELLO AND DEVICEINFO BUILDERS IN DEX ==="

for ($i = 0; $i -lt $lines.Length; $i++) {
    $l = $lines[$i]
    if ($l -match "sdkVersion|deviceModel|OSVersion|resolution|appId|appName|appRegion|mirroring|clockRate|streamMuxConfig") {
        Write-Host "Line $i : $l"
        for ($j = [Math]::Max(0, $i - 5); $j -le [Math]::Min($lines.Length - 1, $i + 10); $j++) {
            if ($lines[$j] -match "Class descriptor|Method name|const-string|invoke-|iput-|iget-") {
                Write-Host "   [$j] $($lines[$j])"
            }
        }
    }
}
