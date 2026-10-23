$targetRoot = "C:\Users\riosv\Desktop\Screen Share TV\Screen-Share-TV\analysis"
$oldAnalysisRoot = "C:\Users\riosv\Desktop\Screen Share TV\analysis"
$scratchDir = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch"

# 1. Create subdirectories
$subDirs = @("reports", "evidence", "notes", "generated", "temp", "apk", "dex", "elf", "ws_capture", "rea_raw")
foreach ($sub in $subDirs) {
    $dirPath = Join-Path $targetRoot $sub
    if (-not (Test-Path $dirPath)) {
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        Write-Host "Created: $dirPath"
    }
}

$movedCount = 0
$correctedFiles = [System.Collections.Generic.List[string]]::new()

# Helper to move file
function Move-OrCopyFile($src, $destDir, $category) {
    if (Test-Path $src) {
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        $destPath = Join-Path $destDir (Get-Item $src).Name
        Copy-Item $src $destPath -Force
        $script:movedCount++
        Write-Host "Moved/Copied ($category): $($src) -> $($destPath)"
    }
}

# 2. Migrate files from oldAnalysisRoot to targetRoot
if (Test-Path $oldAnalysisRoot) {
    Get-ChildItem -Path $oldAnalysisRoot -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($oldAnalysisRoot.Length).TrimStart('\')
        $parts = $rel.Split('\')
        $category = $parts[0]
        $destFolder = Join-Path $targetRoot $category
        Move-OrCopyFile $_.FullName $destFolder $category
    }
}

# 3. Migrate temp scripts from scratch to analysis/temp/
if (Test-Path $scratchDir) {
    Get-ChildItem -Path $scratchDir -Filter "*.ps1" | ForEach-Object {
        Move-OrCopyFile $_.FullName (Join-Path $targetRoot "temp") "temp"
    }
    Get-ChildItem -Path $scratchDir -Filter "*.txt" | ForEach-Object {
        Move-OrCopyFile $_.FullName (Join-Path $targetRoot "evidence") "evidence"
    }
}

# 4. Fix paths inside markdown files in analysis/reports
$reportsDir = Join-Path $targetRoot "reports"
if (Test-Path $reportsDir) {
    Get-ChildItem -Path $reportsDir -Filter "*.md" | ForEach-Object {
        $content = [System.IO.File]::ReadAllText($_.FullName)
        $updated = $content -replace "analysis/notes/", "analysis/temp/" `
                            -replace "C:\\Users\\riosv\\Desktop\\Screen Share TV\\analysis\\", "C:\Users\riosv\Desktop\Screen Share TV\Screen-Share-TV\analysis\"
        if ($content -ne $updated) {
            [System.IO.File]::WriteAllText($_.FullName, $updated)
            $correctedFiles.Add($_.Name)
            Write-Host "Corrected paths in: $($_.Name)"
        }
    }
}

# 5. Generate CENTRAL FILE_INDEX.md
$indexFile = Join-Path $reportsDir "FILE_INDEX.md"
$indexLines = [System.Collections.Generic.List[string]]::new()
$indexLines.Add("# Central File Index: REA Analysis Artifacts")
$indexLines.Add("")
$indexLines.Add("| Archivo | Fecha Creación | Propósito | Ubicación Actual |")
$indexLines.Add("|---|---|---|---|")

Get-ChildItem -Path $targetRoot -Recurse -File | ForEach-Object {
    $relPath = "Screen-Share-TV/analysis/" + $_.FullName.Substring($targetRoot.Length).TrimStart('\').Replace('\', '/')
    $created = $_.CreationTime.ToString("yyyy-MM-dd HH:mm:ss")
    $purpose = "Artefacto REA"

    if ($_.Extension -eq ".md") { $purpose = "Informe de análisis Markdown" }
    elseif ($_.Extension -eq ".ps1") { $purpose = "Script temporal de procesamiento / dexdump" }
    elseif ($_.Extension -eq ".txt") { $purpose = "Evidencia o dump crudo de desensamblado" }
    elseif ($_.Extension -eq ".so") { $purpose = "Biblioteca binaria ELF ARM64" }
    elseif ($_.Extension -eq ".dex") { $purpose = "Ejecutable Dalvik DEX" }
    elseif ($_.Extension -eq ".apk") { $purpose = "Paquete de aplicación Android APK" }

    $indexLines.Add("| `$($_.Name)` | $created | $purpose | `$relPath` |")
}

[System.IO.File]::WriteAllLines($indexFile, $indexLines)
Write-Host "Central Index generated at: $indexFile"
Write-Host "TOTAL MOVED FILES: $movedCount"
