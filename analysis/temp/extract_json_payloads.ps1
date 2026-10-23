$dump15 = "C:\Users\riosv\Desktop\Screen Share TV\analysis\rea_raw\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

$targetClasses = @(
    "Lcom/connectsdk/service/webos/lgcast/common/connection/LGCastCommand;",
    "Lcom/connectsdk/service/webos/lgcast/common/connection/ConnectionManager;"
)

$currentClass = ""
$inTarget = $false

for ($i = 0; $i -lt $lines.Length; $i++) {
    $l = $lines[$i]
    if ($l -match "Class descriptor\s+:\s+'([^']+)'") {
        $currentClass = $matches[1]
        if ($targetClasses -contains $currentClass) {
            $inTarget = $true
            Write-Host "`n=================================================="
            Write-Host "CLASS: $currentClass"
            Write-Host "=================================================="
        } else {
            $inTarget = $false
        }
    }
    elseif ($inTarget) {
        if ($l -match "Method name\s+:\s+'([^']+)'") {
            $mName = $matches[1]
            Write-Host "`n--- Method: $mName ---"
        }
        if ($l -match "const-string|invoke-|iget-|iput-") {
            if ($l -match "cmd|type|request|response|payload|clientKey|sdkVersion|deviceModel|OSVersion|resolution|appId|appName|appRegion|mirroring|video|audio|codec|clockRate|framerate|bitrate|width|height|activeWidth|activeHeight|orientation|frequency|streamMuxConfig|channels|crypto|uibcEnabled|supportedFeatures|screenOrientation|publicKey|masterKeys|HELLO|SET_PARAMETER|GET_PARAMETER") {
                Write-Host "  [$i] $l"
            }
        }
    }
}
