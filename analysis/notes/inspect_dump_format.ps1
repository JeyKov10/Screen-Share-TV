$outFile = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"

$lines = [System.IO.File]::ReadAllLines($outFile)

for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "executeVideoCast|sendData|nativeSendRawData") {
        Write-Host "=================== MATCH AT LINE $i ==================="
        $start = [Math]::Max(0, $i - 5)
        $end = [Math]::Min($lines.Length - 1, $i + 40)
        for ($j = $start; $j -le $end; $j++) {
            Write-Host "[$j] $($lines[$j])"
        }
    }
}
