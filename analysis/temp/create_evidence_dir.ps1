$dir = "C:\Users\riosv\Desktop\Screen Share TV\analysis\evidence"
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-Host "Created $dir"
} else {
    Write-Host "Exists: $dir"
}
