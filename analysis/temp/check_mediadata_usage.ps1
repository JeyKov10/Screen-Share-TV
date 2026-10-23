$dexDump = "C:\Users\riosv\AppData\Local\Android\Sdk\build-tools\36.0.0\dexdump.exe"
$dexFile20 = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_extract\classes20.dex"
$outFile20 = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump20.txt"

if (-not (Test-Path $outFile20)) {
    Write-Host "Running dexdump -d on classes20.dex..."
    & $dexDump -d $dexFile20 > $outFile20
}

$lines15 = [System.IO.File]::ReadAllLines("C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt")
$lines20 = [System.IO.File]::ReadAllLines($outFile20)

function Search-Refs($arr, $fileName) {
    Write-Host "`n=== Searching $fileName ==="
    for ($i = 0; $i -lt $arr.Length; $i++) {
        $line = $arr[$i]
        if ($line -match "Lcom/lge/lib/lgcast/iface/MediaData;|RTPStreamer;\.sendData|nativeSendRawData") {
            Write-Host "Match at line $i : $line"
        }
    }
}

Search-Refs $lines15 "classes15.dex"
Search-Refs $lines20 "classes20.dex"
