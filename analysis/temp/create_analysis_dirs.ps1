$rootDir = "C:\Users\riosv\Desktop\Screen Share TV\analysis"

$subDirs = @("apk", "dex", "elf", "ws_capture", "rea_raw", "prompts", "notes", "reports")

foreach ($sub in $subDirs) {
    $path = Join-Path $rootDir $sub
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Host "Created $path"
    } else {
        Write-Host "Exists: $path"
    }
}
