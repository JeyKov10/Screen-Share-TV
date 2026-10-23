$analysisBase = "C:\Users\riosv\Desktop\Screen Share TV\analysis"
$scratch = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch"

# 1. Copy APKs
Write-Host "Copying APKs..."
Copy-Item "C:\Users\riosv\Desktop\Screen Share TV\LG ThinQ.apk" "$analysisBase\apk\LG ThinQ.apk" -Force
if (Test-Path "$scratch\pulled_apks") {
    Get-ChildItem "$scratch\pulled_apks\*.apk" | ForEach-Object {
        Copy-Item $_.FullName "$analysisBase\apk\$($_.Name)" -Force
        Write-Host "  Copied APK: $($_.Name)"
    }
}

# 2. Copy DEX
Write-Host "Copying DEX files..."
if (Test-Path "$scratch\dex_extract") {
    Get-ChildItem "$scratch\dex_extract\*.dex" | ForEach-Object {
        Copy-Item $_.FullName "$analysisBase\dex\$($_.Name)" -Force
        Write-Host "  Copied DEX: $($_.Name)"
    }
}

# 3. Copy ELF
Write-Host "Copying ELF .so files..."
if (Test-Path "$scratch\libgstreamer-appcast.so") {
    Copy-Item "$scratch\libgstreamer-appcast.so" "$analysisBase\elf\libgstreamer-appcast.so" -Force
    Write-Host "  Copied libgstreamer-appcast.so"
}
if (Test-Path "$scratch\lib_extract") {
    Get-ChildItem "$scratch\lib_extract\*.so" | ForEach-Object {
        Copy-Item $_.FullName "$analysisBase\elf\$($_.Name)" -Force
        Write-Host "  Copied ELF: $($_.Name)"
    }
}

# 4. Copy Dumps and REA raw
Write-Host "Copying Dumps..."
Get-ChildItem "$scratch\*.txt" | ForEach-Object {
    Copy-Item $_.FullName "$analysisBase\rea_raw\$($_.Name)" -Force
    Write-Host "  Copied Raw Dump: $($_.Name)"
}

# 5. Copy PS1 Scripts
Write-Host "Copying PS1 Scripts..."
Get-ChildItem "$scratch\*.ps1" | ForEach-Object {
    Copy-Item $_.FullName "$analysisBase\notes\$($_.Name)" -Force
    Write-Host "  Copied Script: $($_.Name)"
}

Write-Host "`nAll artifacts successfully copied to analysis/ !"
