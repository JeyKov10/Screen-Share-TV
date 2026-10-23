$dump20 = 'C:\Users\riosv\Desktop\Screen Share TV\Screen-Share-TV\analysis\rea_raw\dex_dump20.txt'
$lines = [System.IO.File]::ReadAllLines($dump20)
$evidenceOut = 'C:\Users\riosv\Desktop\Screen Share TV\Screen-Share-TV\analysis\evidence\func_c_disassembly.txt'

$out = [System.Collections.Generic.List[string]]::new()
$out.Add('=== DESENSAMBLADO DE Lcom/lge/lib/lgcast/func/c; ===')

$inClass = $false
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "Class descriptor\s+:\s+'Lcom/lge/lib/lgcast/func/c;'") {
        $inClass = $true
    }
    elseif ($inClass -and $lines[$i] -match "Class descriptor\s+:") {
        $inClass = $false
    }
    if ($inClass) {
        $out.Add("[$i] $($lines[$i])")
    }
}

[System.IO.File]::WriteAllLines($evidenceOut, $out)
Write-Host "func c disassembly saved to $evidenceOut"
