Write-Host "=== SEARCHING C:\Users\riosv\ FOR GSTREAMER / APPCAST / SPLIT APKS / .SO ==="

Get-ChildItem -Path "C:\Users\riosv\" -Recurse -Include "*gstreamer*", "*appcast*", "split_config*.apk", "*.apks" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "MATCH: $($_.FullName) ($($_.Length) bytes)"
}
