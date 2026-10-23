$dump15 = 'C:\Users\riosv\Desktop\Screen Share TV\Screen-Share-TV\analysis\rea_raw\dex_dump.txt'
$dump20 = 'C:\Users\riosv\Desktop\Screen Share TV\Screen-Share-TV\analysis\rea_raw\dex_dump20.txt'
$evidenceOut = 'C:\Users\riosv\Desktop\Screen Share TV\Screen-Share-TV\analysis\evidence\srtp_disassembly_audit.txt'

$out = [System.Collections.Generic.List[string]]::new()
$out.Add('=== DESENSAMBLADO COMPLETO FLUJO SRTP LGCAST ===')
$out.Add('')

function Dump-MethodsInClass($filePath, $className) {
    if (-not (Test-Path $filePath)) { return }
    $lines = [System.IO.File]::ReadAllLines($filePath)
    $out.Add("=== ARCHIVO: $filePath | CLASE: $className ===")
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

Dump-MethodsInClass $dump20 'Lcom/lge/lib/lgcast/iface/MasterKeyFactoryIF;'
Dump-MethodsInClass $dump20 'Lcom/lge/lib/lgcast/iface/MasterKey;'
Dump-MethodsInClass $dump15 'Lcom/connectsdk/service/webos/lgcast/screenmirroring/ScreenMirroringConfig$RTP;'

# Search FIXED_KEY array data block in dump15
$out.Add('=== ARRAY DATA FIXED_KEY ===')
$lines15 = [System.IO.File]::ReadAllLines($dump15)
for ($i = 0; $i -lt $lines15.Length; $i++) {
    if ($lines15[$i] -match "array-data.*FIXED_KEY|42e7b8") {
        for ($j = $i - 5; $j -le $i + 20; $j++) {
            if ($j -ge 0 -and $j -lt $lines15.Length) {
                $out.Add("[$j] $($lines15[$j])")
            }
        }
    }
}

[System.IO.File]::WriteAllLines($evidenceOut, $out)
Write-Host "Disassembly audit evidence saved to $evidenceOut"
