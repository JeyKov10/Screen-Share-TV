$dump15 = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

Write-Host "=== SEARCHING ALL CLASSES IN com/connectsdk/service/webos/lgcast ==="

$inClass = $false
$currentClass = ""

for ($i = 0; $i -lt $lines.Length; $i++) {
    $l = $lines[$i]
    if ($l -match "Class descriptor\s+:\s+'(Lcom/connectsdk/service/webos/lgcast/[^']+)'") {
        $currentClass = $matches[1]
        Write-Host "`nCLASS: $currentClass"
    }
    elseif ($l -match "Method name\s+:\s+'([^']+)'") {
        $mName = $matches[1]
        if ($currentClass -like "*lgcast*") {
            Write-Host "  Method: $mName"
        }
    }
}
