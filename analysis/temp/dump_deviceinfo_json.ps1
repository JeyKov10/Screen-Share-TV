$dump15 = "C:\Users\riosv\Desktop\Screen Share TV\analysis\rea_raw\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

Write-Host "=== SEARCHING FOR DEVICEINFO JSON CONSTRUCTION IN DEX ==="

for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "sdkVersion|deviceModel|OSVersion|appId|appName|appRegion") {
        Write-Host "Found match at line $i :"
        for ($j = [Math]::Max(0, $i - 10); $j -le [Math]::Min($lines.Length - 1, $i + 20); $j++) {
            Write-Host "  [$j] $($lines[$j])"
        }
    }
}
