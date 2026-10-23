$outFile = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"

$lines = [System.IO.File]::ReadAllLines($outFile)

$targetClasses = @(
    "Lcom/connectsdk/service/webos/lgcast/common/streaming/RTPStreaming;",
    "Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer;"
)

$currentClass = ""
$currentMethod = ""
$recording = $false

for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    if ($line -match "Class descriptor\s+:\s+'([^']+)'") {
        $currentClass = $matches[1]
    }
    if ($targetClasses -contains $currentClass) {
        if ($line -match "#[0-9]+\s+:\s+\(in\s+"+[regex]::Escape($currentClass)+"\)") {
            # Method header
            $nameLine = $lines[$i+1]
            $typeLine = $lines[$i+2]
            if ($nameLine -match "name\s+:\s+'([^']+)'" -and $typeLine -match "type\s+:\s+'([^']+)'") {
                $mName = $matches[1]
                # type match
                $mType = [regex]::Match($typeLine, "type\s+:\s+'([^']+)'").Groups[1].Value
                Write-Host ""
                Write-Host "=================================================="
                Write-Host "CLASS: $currentClass"
                Write-Host "METHOD: $mName"
                Write-Host "TYPE: $mType"
                Write-Host "=================================================="

                # Print code block until next method/class
                for ($j = $i; $j -lt $lines.Length; $j++) {
                    $l = $lines[$j]
                    if ($l -match "^\s+#[0-9]+" -or $l -match "Class descriptor") {
                        break
                    }
                    if ($l -match "^\s+[0-9a-f]+:\s+\|[0-9a-f]+\]" -or $l -match "invoke-" -or $l -match "iget-" -or $l -match "iput-" -or $l -match "move-") {
                        Write-Host $l
                    }
                }
            }
        }
    }
}
