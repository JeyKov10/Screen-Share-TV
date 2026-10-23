Add-Type -AssemblyName System.IO.Compression.FileSystem

$apkPath = "C:\Users\riosv\Desktop\Screen Share TV\LG ThinQ.apk"
$zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)

$manifestEntry = $zip.Entries | Where-Object { $_.FullName -eq "AndroidManifest.xml" }
if ($manifestEntry) {
    $stream = $manifestEntry.Open()
    $ms = New-Object System.IO.MemoryStream
    $stream.CopyTo($ms)
    $bytes = $ms.ToArray()
    $stream.Close()
    $ms.Close()

    $enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")
    $text = $enc.GetString($bytes)

    Write-Host "=== AXML STRINGS IN AndroidManifest.xml ==="
    $matches = [regex]::Matches($text, "[\x20-\x7E]{4,}")
    foreach ($m in $matches) {
        $v = $m.Value
        if ($v -match "split|feature|module|dynamic|asset|gstreamer|appcast|extract|lib|download|config|pkg|isFeature|requiredSplit") {
            Write-Host "  Manifest String: $v"
        }
    }
}

$zip.Dispose()
