$dump15 = "C:\Users\riosv\Desktop\Screen Share TV\analysis\rea_raw\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

function Dump-ClassMethods($className) {
    Write-Host "`n=================================================="
    Write-Host "DUMPING ALL METHODS OF $className"
    Write-Host "=================================================="

    $inClass = $false
    $inCode = $false

    for ($i = 0; $i -lt $lines.Length; $i++) {
        $l = $lines[$i]
        if ($l -match "Class descriptor\s+:\s+'$className'") {
            $inClass = $true
        }
        elseif ($inClass -and $l -match "Class descriptor") {
            $inClass = $false
        }

        if ($inClass) {
            if ($l -match "name\s+:\s+'([^']+)'") {
                Write-Host "`n--- Method: $($matches[1]) (line $i) ---"
                # print signature
                if ($i + 1 -lt $lines.Length -and $lines[$i+1] -match "type\s+:\s+'([^']+)'") {
                    Write-Host "    Type: $($matches[1])"
                }
            }
            if ($l -match "^\s+[0-9a-f]+:\s+\|[0-9a-f]+" -or $l -match "const-string" -or $l -match "invoke-" -or $l -match "iget-" -or $l -match "iput-") {
                Write-Host "  $l"
            }
        }
    }
}

Dump-ClassMethods "Lcom/connectsdk/service/webos/lgcast/common/connection/LGCastCommand;"
