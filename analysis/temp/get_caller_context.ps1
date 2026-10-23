$lines = [System.IO.File]::ReadAllLines("C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt")

for ($i = 1169850; $i -le 1169910; $i++) {
    Write-Host "[$i] $($lines[$i])"
}
