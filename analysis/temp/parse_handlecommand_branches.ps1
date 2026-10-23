$lines = [System.IO.File]::ReadAllLines("C:\Users\riosv\Desktop\Screen Share TV\analysis\evidence\handleCommand_switch.txt")

foreach ($l in $lines) {
    if ($l -match "const-string|equals|invoke-|sparse-switch|goto|callOn|ConnectionManager\.[a-z]:") {
        Write-Host $l
    }
}
