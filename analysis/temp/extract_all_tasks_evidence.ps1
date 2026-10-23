$dump15 = "C:\Users\riosv\Desktop\Screen Share TV\Screen-Share-TV\analysis\rea_raw\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)
$evidenceOut = "C:\Users\riosv\Desktop\Screen Share TV\Screen-Share-TV\analysis\evidence\srtp_full_reconstruction_evidence.txt"

$out = [System.Collections.Generic.List[string]]::new()
$out.Add("=== RECONSTRUCCION COMPRENSIVA SRTP Lgcast (EVIDENCE ONLY) ===")
$out.Add("")

function Find-Lines($pattern, $contextBefore = 5, $contextAfter = 15) {
    $out.Add("=== BUSCANDO PATRON: $pattern ===")
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match $pattern) {
            $start = [Math]::Max(0, $i - $contextBefore)
            $end = [Math]::Min($lines.Length - 1, $i + $contextAfter)
            $out.Add("--- Coincidencia en linea $i ---")
            for ($j = $start; $j -le $end; $j++) {
                $out.Add("[$j] $($lines[$j])")
            }
            $out.Add("-----------------------------------")
        }
    }
}

Find-Lines "MasterKeyFactoryIF" 2 10
Find-Lines "createKeys" 2 10
Find-Lines "createFixedKeys" 2 10
Find-Lines "MasterKey" 2 10
Find-Lines "mkiSecureText" 2 10
Find-Lines "keySecureText" 2 10
Find-Lines "masterKeys" 2 10
Find-Lines "AES_128_ICM" 2 10
Find-Lines "HMAC_SHA1_80" 2 10
Find-Lines "enableMki" 2 10
Find-Lines "updateMasterKey" 2 10

[System.IO.File]::WriteAllLines($evidenceOut, $out)
Write-Host "Full reconstruction evidence saved to $evidenceOut"
