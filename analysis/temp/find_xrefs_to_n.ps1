$dump15 = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

$evidenceFile = "C:\Users\riosv\Desktop\Screen Share TV\analysis\evidence\xref_connectionmanager_n.txt"

Write-Host "=== SEARCHING FOR XREFS TO ConnectionManager.n ==="

$xrefList = [System.Collections.Generic.List[int]]::new()

for ($i = 0; $i -lt $lines.Length; $i++) {
    $l = $lines[$i]
    if ($l -match "ConnectionManager;\.n:\(Lcom/connectsdk/service/webos/lgcast/common/connection/ConnectionManager;Lorg/json/JSONObject;\)V") {
        # ignore definition itself at line 1167753
        if ($i -ne 1167753) {
            $xrefList.Add($i)
            Write-Host "Found call at line $i : $l"
        }
    }
}

Write-Host "Total XREFs found: $($xrefList.Count)"

$out = [System.Collections.Generic.List[string]]::new()
$out.Add("=== EVIDENCIA REA: XREFS NATIVOS A ConnectionManager.n(...) ===")
$out.Add("Objetivo: ConnectionManager.n:(Lcom/connectsdk/service/webos/lgcast/common/connection/ConnectionManager;Lorg/json/JSONObject;)V")
$out.Add("Total de Referencias Encontradas: $($xrefList.Count)")
$out.Add("")

foreach ($m in $xrefList) {
    $out.Add("==================================================")
    $out.Add("XREF EN LÍNEA $m :")
    $start = [Math]::Max(0, $m - 20)
    $end = [Math]::Min($lines.Length - 1, $m + 20)
    for ($j = $start; $j -le $end; $j++) {
        $out.Add("[$j] $($lines[$j])")
    }
    $out.Add("==================================================")
    $out.Add("")
}

[System.IO.File]::WriteAllLines($evidenceFile, $out)
Write-Host "Saved XREF evidence to $evidenceFile"
