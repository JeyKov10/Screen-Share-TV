$dump15 = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"

$lines = [System.IO.File]::ReadAllLines($dump15)

Write-Host "=== SEARCHING FOR CALLERS OF RTPStreaming.open & setStreamingConfig IN CLASSES15.DEX ==="

for ($i = 0; $i -lt $lines.Length; $i++) {
    $l = $lines[$i]
    if ($l -match "RTPStreaming;\.open:|RTPStreaming;\.setStreamingConfig:|RTPStreamer;\.setStreamingConfig:|RTPStreamerSetting|masterKey|ssrc|clientKey|SET_PARAMETER") {
        Write-Host "Line $i : $l"
        for ($j = [Math]::Max(0, $i - 10); $j -le [Math]::Min($lines.Length - 1, $i + 15); $j++) {
            if ($lines[$j] -match "Class descriptor|Method name|invoke-|const-string|iget-|iput-") {
                Write-Host "   [$j] $($lines[$j])"
            }
        }
    }
}
