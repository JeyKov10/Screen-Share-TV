$outFile = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"

$lines = [System.IO.File]::ReadAllLines($outFile)

for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "Class descriptor\s+:\s+'Lcom/connectsdk/service/webos/lgcast/common/streaming/RTPStreaming\$1;'") {
        Write-Host "Found RTPStreaming`$1 at line $i"
        for ($j = $i; $j -le $i + 300; $j++) {
            $l = $lines[$j]
            if ($l -match "Class descriptor" -and $j -gt $i + 10) { break }
            Write-Host "[$j] $l"
        }
    }
}
