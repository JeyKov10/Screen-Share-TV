$dump15 = "C:\Users\riosv\Desktop\Screen Share TV\analysis\rea_raw\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

Write-Host "=== LITERAL BYTECODE IN MirroringServiceFunc (1190765-1190820) ==="

for ($i = 1190765; $i -le 1190820; $i++) {
    Write-Host "[$i] $($lines[$i])"
}
