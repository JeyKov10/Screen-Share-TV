Add-Type -AssemblyName System.IO.Compression.FileSystem

$apkPath = "C:\Users\riosv\Desktop\Screen Share TV\LG ThinQ.apk"
$dexDump = "C:\Users\riosv\AppData\Local\Android\Sdk\build-tools\36.0.0\dexdump.exe"
$tempDir = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_extract"

if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
New-Item -ItemType Directory -Path $tempDir | Out-Null

$zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)
foreach ($entry in $zip.Entries) {
    if ($entry.Name -eq "classes15.dex" -or $entry.Name -eq "classes20.dex") {
        $dest = Join-Path $tempDir $entry.Name
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $true)
    }
}
$zip.Dispose()

$classesToFind = @(
    "Lcom/lge/lib/lgcast/iface/VideoCaptureIF;",
    "Lcom/lge/lib/lgcast/iface/MediaData;",
    "Lcom/connectsdk/service/webos/lgcast/common/streaming/RTPStreaming;",
    "Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer;"
)

foreach ($dexFile in (Get-ChildItem $tempDir *.dex)) {
    Write-Host "=================== $null ==================="
    Write-Host "Analyzing $($dexFile.Name)..."

    $output = & $dexDump $dexFile.FullName

    $currentClass = $null
    $inClass = $false

    foreach ($line in $output) {
        if ($line -match "Class descriptor\s+:\s+'([^']+)'") {
            $currentClass = $matches[1]
            if ($classesToFind -contains $currentClass) {
                Write-Host ""
                Write-Host "CLASS FOUND: $currentClass"
                $inClass = $true
            } else {
                $inClass = $false
            }
        }
        elseif ($inClass -and $line -match "name\s+:\s+'([^']+)'") {
            Write-Host "   Method/Field Name: $($matches[1])"
        }
        elseif ($inClass -and $line -match "type\s+:\s+'([^']+)'") {
            Write-Host "   Type: $($matches[1])"
        }
    }
}
