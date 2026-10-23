Add-Type -AssemblyName System.IO.Compression.FileSystem

$apkPath = "C:\Users\riosv\Desktop\Screen Share TV\LG ThinQ.apk"
$zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)
$enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")

Write-Host "Searching for gstreamer in all zip entries..."

foreach ($entry in $zip.Entries) {
    if ($entry.Name.EndsWith(".dex")) {
        $stream = $entry.Open()
        $reader = New-Object System.IO.StreamReader($stream, $enc)
        $text = $reader.ReadToEnd()
        $reader.Close()
        $stream.Close()

        if ($text.Contains("gstreamer")) {
            Write-Host "FOUND 'gstreamer' in $($entry.Name)"
            $matches = [regex]::Matches($text, "[a-zA-Z0-9_\-\./]*gstreamer[a-zA-Z0-9_\-\./]*")
            $unique = $matches | ForEach-Object { $_.Value } | Select-Object -Unique
            foreach ($u in $unique) {
                Write-Host "  Match: $u"
            }
        }
    }
}

$zip.Dispose()
