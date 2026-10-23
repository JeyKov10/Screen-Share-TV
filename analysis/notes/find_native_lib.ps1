Add-Type -AssemblyName System.IO.Compression.FileSystem

$apkPath = "C:\Users\riosv\Desktop\Screen Share TV\LG ThinQ.apk"
$zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)

Write-Host "=== SEARCHING ALL .SO LIBRARIES IN LG ThinQ.apk ==="
$soCount = 0
foreach ($entry in $zip.Entries) {
    if ($entry.FullName -like "*.so" -or $entry.Name -like "*gstreamer*" -or $entry.Name -like "*appcast*") {
        Write-Host "File: $($entry.FullName) ($($entry.Length) bytes)"
        $soCount++
    }
}
Write-Host "Total .so / matching files found: $soCount"

$zip.Dispose()
