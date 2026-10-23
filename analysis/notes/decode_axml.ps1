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

    # Simple ASCII/UTF16 string extractor
    $strUtf8 = [System.Text.Encoding]::UTF8.GetString($bytes)
    $strUtf16 = [System.Text.Encoding]::Unicode.GetString($bytes)

    Write-Host "=== UTF8 STRINGS IN MANIFEST ==="
    $m1 = [regex]::Matches($strUtf8, "[\x20-\x7E]{3,}")
    foreach ($m in $m1) {
        $v = $m.Value
        if ($v -match "split|feature|module|dynamic|asset|gstreamer|appcast|extract|lib|download|config|pkg|isFeature|requiredSplit|com.lge|com.connectsdk") {
            Write-Host "  UTF8: $v"
        }
    }

    Write-Host "=== UTF16 STRINGS IN MANIFEST ==="
    $m2 = [regex]::Matches($strUtf16, "[\x20-\x7E]{3,}")
    foreach ($m in $m2) {
        $v = $m.Value
        if ($v -match "split|feature|module|dynamic|asset|gstreamer|appcast|extract|lib|download|config|pkg|isFeature|requiredSplit|com.lge|com.connectsdk") {
            Write-Host "  UTF16: $v"
        }
    }
}

$zip.Dispose()
