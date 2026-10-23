$dump15 = "C:\Users\riosv\Desktop\Screen Share TV\analysis\rea_raw\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

function Dump-MethodExact($className, $methodName) {
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
            Write-Host "Found $methodName at line $i :"
            for ($j = $i; $j -lt $lines.Length; $j++) {
                $l = $lines[$j]
                if ($l -match "^\s+#\d+" -and $j -gt $i + 5) { break }
                if ($l -match "Class descriptor") { break }
                if ($l -match "^\s+[0-9a-f]+:\s+\|[0-9a-f]+" -or $l -match "const-string" -or $l -match "invoke-") {
                    Write-Host "  $l"
                }
            }
        }
    }
}

Dump-MethodExact "Lcom/connectsdk/service/webos/lgcast/screenmirroring/capability/MirroringSourceCapability;" "toJSONObject"
Dump-MethodExact "Lcom/connectsdk/service/webos/lgcast/screenmirroring/capability/VideoSizeInfo;" "toJSONObject"
Dump-MethodExact "Lcom/connectsdk/service/webos/lgcast/screenmirroring/capability/MirroringSinkCapability;" "toJSONObject"
