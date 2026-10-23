$dump15 = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

Write-Host "=== CALLER CONTEXT FOR LINE 2141205 ==="

for ($i = 2141150; $i -le 2141230; $i++) {
    Write-Host "[$i] $($lines[$i])"
}
