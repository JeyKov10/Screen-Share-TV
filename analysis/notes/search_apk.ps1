Add-Type -AssemblyName System.IO.Compression.FileSystem

$apkPath = "C:\Users\riosv\Desktop\Screen Share TV\LG ThinQ.apk"
$zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)
$targets = @("VideoCaptureIF", "MediaData", "RTPStreaming", "RTPStreamer")
$enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")

Write-Host "Searching in $apkPath..."

foreach ($entry in $zip.Entries) {
    if ($entry.Name.EndsWith(".dex")) {
        $stream = $entry.Open()
        $reader = New-Object System.IO.StreamReader($stream, $enc)
        $text = $reader.ReadToEnd()
        $reader.Close()
        $stream.Close()

        foreach ($t in $targets) {
            if ($text.Contains($t)) {
                Write-Host "FOUND '$t' in $($entry.Name)"
                $pattern = "L[a-zA-Z0-9_/$]*" + [regex]::Escape($t) + "[a-zA-Z0-9_/$]*;"
                $matches = [regex]::Matches($text, $pattern)
                $unique = $matches | ForEach-Object { $_.Value } | Select-Object -Unique
                foreach ($u in $unique) {
                    Write-Host "  Descriptor: $u"
                }
            }
        }
    }
}

$zip.Dispose()
