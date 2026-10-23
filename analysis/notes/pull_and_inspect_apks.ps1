Add-Type -AssemblyName System.IO.Compression.FileSystem

$outDir = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\pulled_apks"
if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
New-Item -ItemType Directory -Path $outDir | Out-Null

$deviceSerial = "A6N7AUE6UWGE6T6D"

$apkRemotePaths = @(
    "/data/app/~~lpGQ4cy1KH2fGsDvIkjLoA==/com.lgeha.nuts-iaPAx0ffKSQGLuMISRA8ZQ==/base.apk",
    "/data/app/~~lpGQ4cy1KH2fGsDvIkjLoA==/com.lgeha.nuts-iaPAx0ffKSQGLuMISRA8ZQ==/split_config.arm64_v8a.apk",
    "/data/app/~~lpGQ4cy1KH2fGsDvIkjLoA==/com.lgeha.nuts-iaPAx0ffKSQGLuMISRA8ZQ==/split_config.xxhdpi.apk",
    "/data/app/~~lpGQ4cy1KH2fGsDvIkjLoA==/com.lgeha.nuts-iaPAx0ffKSQGLuMISRA8ZQ==/split_hejhomenative.apk",
    "/data/app/~~lpGQ4cy1KH2fGsDvIkjLoA==/com.lgeha.nuts-iaPAx0ffKSQGLuMISRA8ZQ==/split_hejhomenative.config.arm64_v8a.apk",
    "/data/app/~~lpGQ4cy1KH2fGsDvIkjLoA==/com.lgeha.nuts-iaPAx0ffKSQGLuMISRA8ZQ==/split_hejhomenative.config.xxhdpi.apk"
)

Write-Host "=== PULLING APKS FROM DEVICE $deviceSerial ==="
foreach ($remote in $apkRemotePaths) {
    $fileName = Split-Path $remote -Leaf
    $localPath = Join-Path $outDir $fileName
    Write-Host "Pulling $fileName..."
    adb -s $deviceSerial pull $remote $localPath
}

Write-Host "`n=== INSPECTING PULLED APKS ==="

foreach ($apkFile in (Get-ChildItem $outDir *.apk)) {
    Write-Host "`n--------------------------------------------------"
    Write-Host "APK: $($apkFile.Name) ($($apkFile.Length) bytes)"
    Write-Host "Local Path: $($apkFile.FullName)"

    $zip = [System.IO.Compression.ZipFile]::OpenRead($apkFile.FullName)

    $arm64Entries = $zip.Entries | Where-Object { $_.FullName -like "lib/arm64-v8a/*" }
    $armv7Entries = $zip.Entries | Where-Object { $_.FullName -like "lib/armeabi-v7a/*" }

    Write-Host "Contenido lib/arm64-v8a/ ($($arm64Entries.Count) archivos):"
    foreach ($e in $arm64Entries) {
        Write-Host "  - $($e.FullName) ($($e.Length) bytes)"
        if ($e.Name -eq "libgstreamer_android.so" -or $e.Name -eq "libgstreamer-appcast.so") {
            Write-Host "    >>> TARGET FOUND! <<<"
            Write-Host "    RUTA EXACTA: $($e.FullName)"
            Write-Host "    TAMAÑO: $($e.Length) bytes"
            Write-Host "    APK CONTENEDOR: $($apkFile.Name)"
        }
    }

    Write-Host "Contenido lib/armeabi-v7a/ ($($armv7Entries.Count) archivos):"
    foreach ($e in $armv7Entries) {
        Write-Host "  - $($e.FullName) ($($e.Length) bytes)"
        if ($e.Name -eq "libgstreamer_android.so" -or $e.Name -eq "libgstreamer-appcast.so") {
            Write-Host "    >>> TARGET FOUND! <<<"
            Write-Host "    RUTA EXACTA: $($e.FullName)"
            Write-Host "    TAMAÑO: $($e.Length) bytes"
            Write-Host "    APK CONTENEDOR: $($apkFile.Name)"
        }
    }

    $zip.Dispose()
}
