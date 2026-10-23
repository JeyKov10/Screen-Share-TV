$dump15 = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

$evidenceFile = "C:\Users\riosv\Desktop\Screen Share TV\analysis\evidence\xref_connectionmanager_n.txt"

$out = [System.Collections.Generic.List[string]]::new()
$out.Add("=== EVIDENCIA REA: XREFS NATIVOS A ConnectionManager.n(...) ===")
$out.Add("Objetivo: ConnectionManager.n:(Lcom/connectsdk/service/webos/lgcast/common/connection/ConnectionManager;Lorg/json/JSONObject;)V")
$out.Add("Total de Invocaciones Directas (invoke-static): 1")
$out.Add("Clase Llamadora: hna.aa.a (Lambda / Runnable desazucarado de ConnectionManager)")
$out.Add("Método Llamador: public final void hna.aa.a.run()")
$out.Add("Offset DEX: 0x005fd2c0 (Línea 2141202 - 2141206)")
$out.Add("")

$out.Add("==================================================")
$out.Add("1. INVOCADOR DIRECTO (invoke-static en hna.aa.a.run):")
$out.Add("==================================================")
for ($i = 2141180; $i -le 2141215; $i++) {
    $out.Add("[$i] $($lines[$i])")
}

$out.Add("")
$out.Add("==================================================")
$out.Add("2. INSTANCIADOR DEL RUNNABLE (invoke-direct hna.aa.a.<init> en ConnectionManager):")
$out.Add("==================================================")
for ($i = 1167180; $i -le 1167210; $i++) {
    $out.Add("[$i] $($lines[$i])")
}

[System.IO.File]::WriteAllLines($evidenceFile, $out)
Write-Host "Saved full XREF evidence to $evidenceFile"
