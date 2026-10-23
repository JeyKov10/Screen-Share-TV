$dump15 = "C:\Users\riosv\Desktop\Screen Share TV\analysis\rea_raw\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

Write-Host "=== SEARCHING FOR DEVICEINFO KEYS IN DEX ==="

for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "const-string.*(?:sdkVersion|deviceModel|OSVersion|appId|appName|appRegion)") {
        Write-Host "`nMatch at line $i : $($lines[$i])"
        for ($j = [Math]::Max(0, $i - 5); $j -le [Math]::Min($lines.Length - 1, $i + 20); $j++) {
            if ($lines[$j] -match "^\s+[0-9a-f]+:\s+\|[0-9a-f]+" -or $lines[$j] -match "const-string" -or $lines[$j] -match "invoke-") {
                Write-Host "  [$j] $($lines[$j])"
            }
        }
    }
}
