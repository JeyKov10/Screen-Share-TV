$outFile = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"

$lines = [System.IO.File]::ReadAllLines($outFile)

function Dump-MethodCode($className, $methodName) {
    Write-Host "`n=================================================="
    Write-Host "CLASS: $className | METHOD: $methodName"
    Write-Host "=================================================="

    $inClass = $false
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match "Class descriptor\s+:\s+'$className'") {
            $inClass = $true
        }
        elseif ($inClass -and $lines[$i] -match "Class descriptor") {
            $inClass = $false
        }

        if ($inClass -and $lines[$i] -match "name\s+:\s+'$methodName'") {
            Write-Host "Found method at line $i :"
            # Print signature
            for ($k = $i - 2; $k -le $i + 10; $k++) {
                Write-Host "  $($lines[$k])"
            }
            Write-Host "--- CODE ---"
            for ($j = $i; $j -lt $lines.Length; $j++) {
                $l = $lines[$j]
                if ($l -match "^\s+#\d+" -and $j -gt $i + 5) { break }
                if ($l -match "Class descriptor") { break }
                if ($l -match "^\s+[0-9a-f]+:\s+\|[0-9a-f]+" -or $l -match "invoke-" -or $l -match "iget-" -or $l -match "iput-" -or $l -match "move-") {
                    Write-Host "  $l"
                }
            }
        }
    }
}

Dump-MethodCode "Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer;" "sendData"
Dump-MethodCode "Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer;" "nativeSendRawData"
Dump-MethodCode "Lcom/connectsdk/service/webos/lgcast/common/streaming/RTPStreaming;" "executeVideoCast"
