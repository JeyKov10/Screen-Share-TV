$soPath = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\libgstreamer-appcast.so"
$bytes = [System.IO.File]::ReadAllBytes($soPath)

Write-Host "File size: $($bytes.Length) bytes"

# Search for the string 'nativeSendRawData' offset
$enc = [System.Text.Encoding]::ASCII
$str = "nativeSendRawData"
$strBytes = $enc.GetBytes($str)

for ($i = 0; $i -lt $bytes.Length - $strBytes.Length; $i++) {
    $found = $true
    for ($j = 0; $j -lt $strBytes.Length; $j++) {
        if ($bytes[$i + $j] -ne $strBytes[$j]) {
            $found = $false
            break
        }
    }
    if ($found) {
        Write-Host ("String 'nativeSendRawData' at offset 0x{0:X8}" -f $i)
    }
}

$str2 = "(IJ[B)Z"
$strBytes2 = $enc.GetBytes($str2)
for ($i = 0; $i -lt $bytes.Length - $strBytes2.Length; $i++) {
    $found = $true
    for ($j = 0; $j -lt $strBytes2.Length; $j++) {
        if ($bytes[$i + $j] -ne $strBytes2[$j]) {
            $found = $false
            break
        }
    }
    if ($found) {
        Write-Host ("String '(IJ[B)Z' at offset 0x{0:X8}" -f $i)
    }
}

$str3 = "gst_native_send_data"
$strBytes3 = $enc.GetBytes($str3)
for ($i = 0; $i -lt $bytes.Length - $strBytes3.Length; $i++) {
    $found = $true
    for ($j = 0; $j -lt $strBytes3.Length; $j++) {
        if ($bytes[$i + $j] -ne $strBytes3[$j]) {
            $found = $false
            break
        }
    }
    if ($found) {
        Write-Host ("String 'gst_native_send_data' at offset 0x{0:X8}" -f $i)
    }
}
