Write-Host "=== SEARCHING C:\Users\riosv\ FOR ALL .APK FILES ==="

Get-ChildItem -Path "C:\Users\riosv\" -Recurse -Include "*.apk" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "APK: $($_.FullName) ($($_.Length) bytes)"
}
