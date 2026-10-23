$dump15 = 'C:\Users\riosv\Desktop\Screen Share TV\Screen-Share-TV\analysis\rea_raw\dex_dump.txt'
$lines = [System.IO.File]::ReadAllLines($dump15)
$evidenceOut = 'C:\Users\riosv\Desktop\Screen Share TV\Screen-Share-TV\analysis\evidence\masterkey_structure_evidence.txt'

$out = [System.Collections.Generic.List[string]]::new()
$out.Add('=== RECONSTRUCCION DETALLADA DE MasterKey Y MasterKeyFactoryIF ===')
$out.Add('')

function Dump-ClassBlock($className) {
    $out.Add("=== CLASE: $className ===")
    $inClass = $false
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match "Class descriptor\s+:\s+'$className'") {
            $inClass = $true
        }
        elseif ($inClass -and $lines[$i] -match "Class descriptor\s+:") {
            $inClass = $false
        }
        if ($inClass) {
            $out.Add("[$i] $($lines[$i])")
        }
    }
}

Dump-ClassBlock 'Lcom/lge/lib/lgcast/iface/MasterKey;'
Dump-ClassBlock 'Lcom/lge/lib/lgcast/iface/MasterKeyFactoryIF;'
Dump-ClassBlock 'Lcom/connectsdk/service/webos/lgcast/screenmirroring/ScreenMirroringConfig$RTP;'

$out.Add('=== BUSQUEDA DE FIXED_KEY EN DEX ===')
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "FIXED_KEY") {
        $start = [Math]::Max(0, $i - 5)
        $end = [Math]::Min($lines.Length - 1, $i + 15)
        for ($j = $start; $j -le $end; $j++) {
            $out.Add("[$j] $($lines[$j])")
        }
    }
}

[System.IO.File]::WriteAllLines($evidenceOut, $out)
Write-Host "MasterKey structure evidence saved to $evidenceOut"
