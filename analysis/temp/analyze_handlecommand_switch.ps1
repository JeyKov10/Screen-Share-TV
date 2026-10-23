$dump15 = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

$evidenceFile = "C:\Users\riosv\Desktop\Screen Share TV\analysis\evidence\handleCommand_switch.txt"

Write-Host "=== DUMPING handleCommand (1167495 to 1167675) ==="

$out = @()
$out += "=== EVIDENCIA REA: ANALISIS DE ConnectionManager.handleCommand(JSONObject) ==="
$out += "Offset: 0x00424ccc | Líneas DEX: 1167495 - 1167675"
$out += ""

for ($i = 1167495; $i -le 1167675; $i++) {
    $out += "[$i] $($lines[$i])"
}

[System.IO.File]::WriteAllLines($evidenceFile, $out)
Write-Host "Saved evidence to $evidenceFile"
