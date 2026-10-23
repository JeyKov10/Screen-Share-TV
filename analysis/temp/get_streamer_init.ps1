$lines = [System.IO.File]::ReadAllLines("C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt")

$inClass = $false
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "Class descriptor\s+:\s+'Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer;'") {
        $inClass = $true
    }
    elseif ($inClass -and $lines[$i] -match "Class descriptor") {
        $inClass = $false
    }

    if ($inClass -and $lines[$i] -match "name\s+:\s+'initialize|onGStreamerInitialized|<clinit>'") {
        Write-Host "=================== LINE $i ==================="
        Write-Host "Line $i : $($lines[$i])"
        for ($j = $i; $j -le $i + 40; $j++) {
            Write-Host "  [$j] $($lines[$j])"
        }
    }
}
