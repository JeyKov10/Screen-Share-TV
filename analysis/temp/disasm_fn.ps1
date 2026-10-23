$soPath = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\libgstreamer-appcast.so"
$bytes = [System.IO.File]::ReadAllBytes($soPath)

function Read-String($off) {
    int $len = 0
    while ($off + $len -lt $bytes.Length -and $bytes[$off + $len] -ne 0) { $len++ }
    return [System.Text.Encoding]::ASCII.GetString($bytes, $off, $len)
}

Write-Host "=== VERIFYING JNINativeMethod TABLE AT OFFSET 0x0000AAC8 ==="
# Section .data offset is 0x0000AAC8 (RVA 0x00012AC8)
# Relocations in .rela.dyn set the initial addends for each pointer field:

$entries = @(
    @{ NameRva=0x3A6D; SigRva=0x2E38; FnRva=0x84BC; SlotOff=0xAAC8 },
    @{ NameRva=0x4156; SigRva=0x2E38; FnRva=0x853C; SlotOff=0xAAE0 },
    @{ NameRva=0x384E; SigRva=0x385E; FnRva=0x85F0; SlotOff=0xAAF8 },
    @{ NameRva=0x3D81; SigRva=0x385E; FnRva=0x86CC; SlotOff=0xAB10 },
    @{ NameRva=0x36C4; SigRva=0x4707; FnRva=0x8748; SlotOff=0xAB28 },
    @{ NameRva=0x3B8B; SigRva=0x385E; FnRva=0x891C; SlotOff=0xAB40 },
    @{ NameRva=0x2F87; SigRva=0x2E38; FnRva=0x8A68; SlotOff=0xAB58 },
    @{ NameRva=0x36D6; SigRva=0x3BC1; FnRva=0x8A98; SlotOff=0xAB70 }
)

$idx = 0
foreach ($e in $entries) {
    $nStr = Read-String $e.NameRva
    $sStr = Read-String $e.SigRva
    Write-Host ("Entry [{0}] | Slot FileOffset: 0x{1:X8} (RVA 0x{2:X8})" -f $idx, $e.SlotOff, ($e.SlotOff + 0x8000))
    Write-Host ("  -> Name  : RVA 0x{0:X8} ('{1}')" -f $e.NameRva, $nStr)
    Write-Host ("  -> Sig   : RVA 0x{0:X8} ('{1}')" -f $e.SigRva, $sStr)
    Write-Host ("  -> FnPtr : RVA 0x{0:X8} (FileOffset 0x{0:X8})" -f $e.FnRva)
    $idx++
}
