Add-Type -AssemblyName System.IO.Compression.FileSystem

$apkPath = "C:\Users\riosv\Desktop\Screen Share TV\LG ThinQ.apk"
$zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)

Write-Host "=== METADATA FILES IN META-INF AND ASSETS ==="
foreach ($entry in $zip.Entries) {
    if ($entry.FullName.StartsWith("META-INF/") -or $entry.FullName.StartsWith("assets/")) {
        if ($entry.Name -like "*split*" -or $entry.Name -like "*fused*" -or $entry.Name -like "*pb*" -or $entry.Name -like "*json*" -or $entry.Name -like "*meta*" -or $entry.Name -like "*version*") {
            Write-Host "$($entry.FullName) ($($entry.Length) bytes)"
        }
    }
}

$zip.Dispose()
