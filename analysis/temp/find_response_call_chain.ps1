$dump15 = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

Write-Host "=== SEARCHING FOR MirroringSinkCapability CONSTRUCTOR CALLS ==="
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "MirroringSinkCapability;\.<init>:\(Lorg/json/JSONObject;\)V") {
        Write-Host "Match at line $i : $($lines[$i])"
        for ($j = [Math]::Max(0, $i - 15); $j -le [Math]::Min($lines.Length - 1, $i + 15); $j++) {
            Write-Host "  [$j] $($lines[$j])"
        }
    }
}

Write-Host "`n=== SEARCHING FOR GET_PARAMETER_RESPONSE AND SET_PARAMETER_RESPONSE HANDLERS ==="
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "GET_PARAMETER_RESPONSE|SET_PARAMETER_RESPONSE") {
        Write-Host "Match at line $i : $($lines[$i])"
        for ($j = [Math]::Max(0, $i - 5); $j -le [Math]::Min($lines.Length - 1, $i + 15); $j++) {
            Write-Host "  [$j] $($lines[$j])"
        }
    }
}
