Add-Type -AssemblyName System.IO.Compression.FileSystem

$apkPath = "C:\Users\riosv\Desktop\Screen Share TV\LG ThinQ.apk"
$tempDir = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\www_extract"

if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
New-Item -ItemType Directory -Path $tempDir | Out-Null

$zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)
foreach ($entry in $zip.Entries) {
    if ($entry.FullName -eq "assets/www.zip") {
        Write-Host "Extracting assets/www.zip..."
        $zipDest = Join-Path $tempDir $entry.Name
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $zipDest, $true)

        # Open inner zip
        $innerZip = [System.IO.Compression.ZipFile]::OpenRead($zipDest)
        Write-Host "Searching in www.zip for .so, gstreamer, appcast..."
        foreach ($innerEntry in $innerZip.Entries) {
            if ($innerEntry.Name -like "*.so" -or $innerEntry.Name -like "*gstreamer*" -or $innerEntry.Name -like "*appcast*") {
                Write-Host "  FOUND: $($innerEntry.FullName) ($($innerEntry.Length) bytes)"
            }
        }
        $innerZip.Dispose()
    }
}
$zip.Dispose()
