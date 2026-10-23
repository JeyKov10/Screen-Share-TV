$dump15 = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

Write-Host "=== BLOCK 1: LGCastCommand (GET_PARAMETER_RESPONSE and deviceInfo) ==="
$start1 = [Math]::Max(0, 1169147 - 100)
$end1 = [Math]::Min($lines.Length - 1, 1169240 + 100)
for ($i = $start1; $i -le $end1; $i++) {
    Write-Host "[$i] $($lines[$i])"
}

Write-Host "`n=== BLOCK 2: MirroringSinkCapability (deviceInfo parsing) ==="
$start2 = [Math]::Max(0, 1187598 - 150)
$end2 = [Math]::Min($lines.Length - 1, 1187598 + 150)
for ($i = $start2; $i -le $end2; $i++) {
    Write-Host "[$i] $($lines[$i])"
}
