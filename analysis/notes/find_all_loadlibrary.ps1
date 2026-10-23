Add-Type -AssemblyName System.IO.Compression.FileSystem

$apkPath = "C:\Users\riosv\Desktop\Screen Share TV\LG ThinQ.apk"
$zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)
$enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")

Write-Host "Searching for System.loadLibrary in all dex files..."

$dexDump = "C:\Users\riosv\AppData\Local\Android\Sdk\build-tools\36.0.0\dexdump.exe"
$tempDir = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_extract"

foreach ($entry in $zip.Entries) {
    if ($entry.Name.EndsWith(".dex")) {
        $dest = Join-Path $tempDir $entry.Name
        if (-not (Test-Path $dest)) {
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $true)
        }
        $txt = & $dexDump -d $dest
        for ($i = 0; $i -lt $txt.Length; $i++) {
            if ($txt[$i] -match "loadLibrary") {
                Write-Host "In $($entry.Name):"
                for ($j = [Math]::Max(0, $i - 5); $j -le [Math]::Min($txt.Length - 1, $i + 2); $j++) {
                    Write-Host "  $($txt[$j])"
                }
            }
        }
    }
}

$zip.Dispose()
