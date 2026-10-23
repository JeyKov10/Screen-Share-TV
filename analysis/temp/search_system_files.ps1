Write-Host "=== SEARCHING FOR APK / APKS / SO / GSTREAMER FILES ON DISK ==="

$pathsToSearch = @(
    "C:\Users\riosv\Desktop\",
    "C:\Users\riosv\Downloads\",
    "C:\Users\riosv\AppData\Local\Temp\",
    "C:\Users\riosv\.android\"
)

foreach ($p in $pathsToSearch) {
    if (Test-Path $p) {
        Write-Host "Searching in $p..."
        Get-ChildItem -Path $p -Recurse -Include "*.apk", "*.apks", "*gstreamer*", "*appcast*", "split_config*.apk", "*.so" -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "FOUND FILE: $($_.FullName) ($($_.Length) bytes)"
        }
    }
}
