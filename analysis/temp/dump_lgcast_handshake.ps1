$dump15 = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\dex_dump.txt"
$lines = [System.IO.File]::ReadAllLines($dump15)

$targetClasses = @(
    "Lcom/connectsdk/service/webos/lgcast/common/connection/LGCastCommand;",
    "Lcom/connectsdk/service/webos/lgcast/common/connection/ConnectionManager;",
    "Lcom/connectsdk/service/webos/lgcast/screenmirroring/service/MirroringServiceFunc;",
    "Lcom/connectsdk/service/webos/lgcast/screenmirroring/service/MirroringService;",
    "Lcom/connectsdk/service/webos/lgcast/screenmirroring/api/ScreenMirroringApi;"
)

$currentClass = ""
$inTarget = $false

for ($i = 0; $i -lt $lines.Length; $i++) {
    $l = $lines[$i]
    if ($l -match "Class descriptor\s+:\s+'([^']+)'") {
        $currentClass = $matches[1]
        if ($targetClasses -contains $currentClass) {
            $inTarget = $true
            Write-Host "`n=================== CLASS: $currentClass ==================="
        } else {
            $inTarget = $false
        }
    }
    elseif ($inTarget) {
        if ($l -match "Method name|const-string|invoke-|iput-|iget-") {
            if ($l -match "HELLO|CONNECT|SET_PARAMETER|GET_PARAMETER|PLAY|START|ssrc|masterKey|cipherType|authType|videoPort|audioPort|clientKey|open|setStreamingConfig") {
                Write-Host "Line $i : $l"
            }
        }
    }
}
