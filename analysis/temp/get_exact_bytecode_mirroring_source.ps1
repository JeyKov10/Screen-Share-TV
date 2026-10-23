$dump15 = "C:\Users\riosv\Desktop\Screen Share TV\analysis\rea_raw\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

Write-Host "=== LITERAL BYTECODE OF MirroringSourceCapability.toJSONObject() ==="

for ($i = 1188101; $i -le 1188205; $i++) {
    Write-Host "[$i] $($lines[$i])"
}
