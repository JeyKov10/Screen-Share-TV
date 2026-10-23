Add-Type -AssemblyName System.IO.Compression.FileSystem

$apkPath = "C:\Users\riosv\Desktop\Screen Share TV\LG ThinQ.apk"
$zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)

$manifestEntry = $zip.Entries | Where-Object { $_.FullName -eq "AndroidManifest.xml" }
$stream = $manifestEntry.Open()
$ms = New-Object System.IO.MemoryStream
$stream.CopyTo($ms)
$bytes = $ms.ToArray()
$stream.Close()
$ms.Close()
$zip.Dispose()

# Extract all ASCII / UTF-16 strings in order from AXML string pool
$strings = @()
for ($i = 0; $i -lt $bytes.Length - 4; $i += 2) {
    if ($bytes[$i] -ge 0x20 -and $bytes[$i] -le 0x7e -and $bytes[$i+1] -eq 0) {
        $start = $i
        $str = ""
        while ($i -lt $bytes.Length - 1 -and $bytes[$i] -ge 0x20 -and $bytes[$i] -le 0x7e -and $bytes[$i+1] -eq 0) {
            $str += [char]$bytes[$i]
            $i += 2
        }
        if ($str.Length -ge 3) {
            $strings += $str
        }
    }
}

Write-Host "=== AXML STRINGS FOUND ==="
foreach ($s in $strings) {
    if ($s -match "split|vending|fused|asset|pack|gstreamer|appcast|native|lib") {
        Write-Host "  String: $s"
    }
}
