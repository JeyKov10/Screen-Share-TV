$dexDump = "C:\Users\riosv\AppData\Local\Android\Sdk\build-tools\36.0.0\dexdump.exe"
$dexFile = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_extract\classes15.dex"
$outFile = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"

if (-not (Test-Path $outFile)) {
    Write-Host "Running dexdump -d..."
    & $dexDump -d $dexFile > $outFile
}

Write-Host "Reading $outFile..."
$lines = [System.IO.File]::ReadAllLines($outFile)

$inTargetClass = $false
$inTargetMethod = $false
$targetClasses = @(
    "Lcom/connectsdk/service/webos/lgcast/common/streaming/RTPStreaming;",
    "Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer;"
)
$targetMethods = @("executeVideoCast", "sendData", "nativeSendRawData")

for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    if ($line -match "Class descriptor\s+:\s+'([^']+)'") {
        $cls = $matches[1]
        if ($targetClasses -contains $cls) {
            $inTargetClass = $true
            Write-Host "=================== CLASS: $cls ==================="
        } else {
            $inTargetClass = $false
        }
    }
    elseif ($inTargetClass -and $line -match "Method name\s+:\s+'([^']+)'") {
        $mName = $matches[1]
        if ($targetMethods -contains $mName) {
            $inTargetMethod = $true
            Write-Host "`n--- METHOD: $mName ---"
            # Print signature
            for ($j = $i; $j -lt [Math]::Min($i + 15, $lines.Length); $j++) {
                if ($lines[$j] -match "type\s+:\s+'([^']+)'") {
                    Write-Host "Signature/Type: $($matches[1])"
                }
            }
        } else {
            $inTargetMethod = $false
        }
    }
    elseif ($inTargetClass -and $inTargetMethod) {
        if ($line -match "^\s+[0-9a-f]+:") {
            Write-Host $line
        }
    }
}
