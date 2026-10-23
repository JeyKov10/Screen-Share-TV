Add-Type -AssemblyName System.IO.Compression.FileSystem

$apkPath = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\pulled_apks\split_config.arm64_v8a.apk"
$outSo = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\libgstreamer-appcast.so"

$zip = [System.IO.Compression.ZipFile]::OpenRead($apkPath)
$entry = $zip.Entries | Where-Object { $_.FullName -like "*libgstreamer-appcast.so" }
if ($entry) {
    Write-Host "Extracting $($entry.FullName) ($($entry.Length) bytes) to $outSo..."
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $outSo, $true)
}
$zip.Dispose()

if (Test-Path $outSo) {
    $bytes = [System.IO.File]::ReadAllBytes($outSo)
    $enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")
    $text = $enc.GetString($bytes)

    Write-Host "`n=== ALL ASCII STRINGS IN libgstreamer-appcast.so ==="
    $matches = [regex]::Matches($text, "[\x20-\x7E]{3,}")
    for ($i = 0; $i -lt $matches.Count; $i++) {
        $v = $matches[$i].Value
        $off = $matches[$i].Index
        Write-Host ("0x{0:X8} : {1}" -f $off, $v)
    }
}
