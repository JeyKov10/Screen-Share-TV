Add-Type -AssemblyName System.IO.Compression.FileSystem

$apkPath = "C:\Users\riosv\Desktop\Screen Share TV\LG ThinQ.apk"
$zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)

Write-Host "=== LISTING FILES IN LG ThinQ.apk MATCHING 'lib', 'asset', 'gst', 'appcast' ==="
foreach ($entry in $zip.Entries) {
    if ($entry.FullName -like "*lib*" -or $entry.FullName -like "*gst*" -or $entry.FullName -like "*appcast*" -or $entry.FullName -like "*.enc" -or $entry.FullName -like "*.zip") {
        Write-Host "$($entry.FullName) ($($entry.Length) bytes)"
    }
}

$zip.Dispose()
