$dump15 = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"
$dump20 = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump20.txt"

function Search-Dump($filePath, $fileName) {
    Write-Host "`n=== SEARCHING IN $fileName ==="
    $lines = [System.IO.File]::ReadAllLines($filePath)

    $inClass = $false
    $currentClass = ""

    for ($i = 0; $i -lt $lines.Length; $i++) {
        $l = $lines[$i]
        if ($l -match "Class descriptor\s+:\s+'(Lcom/connectsdk/service/webos/lgcast/[^']+|Lcom/lge/lib/lgcast/[^']+)'") {
            $currentClass = $matches[1]
            $inClass = $true
        }
        elseif ($inClass -and $l -match "Class descriptor") {
            $inClass = $false
        }

        if ($inClass -and $l -match "deviceInfo|GET_PARAMETER_RESPONSE") {
            Write-Host "MATCH IN $currentClass AT LINE $i : $l"
        }
    }
}

Search-Dump $dump15 "classes15.dex"
if (Test-Path $dump20) { Search-Dump $dump20 "classes20.dex" }
