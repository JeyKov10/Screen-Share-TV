$soPath = "C:\Users\riosv\AppData\Local\Google\AndroidStudio2026.2.1\projects\screen share tv.ee0acb51\.artifacts\2b1c3bac-1c04-495b-a449-5408421c84fe\scratch\lib_extract\libqs_jni.so"

$bytes = [System.IO.File]::ReadAllBytes($soPath)
$enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")
$text = $enc.GetString($bytes)

$queries = @("nativeSendRawData", "RTPStreamer", "gstreamer", "JNI_OnLoad", "Java_")

Write-Host "=== SEARCHING IN libqs_jni.so ($($bytes.Length) bytes) ==="

foreach ($q in $queries) {
    if ($text.Contains($q)) {
        Write-Host "FOUND '$q' in libqs_jni.so!"
        $matches = [regex]::Matches($text, "[a-zA-Z0-9_$%#@\-/\.\:]*" + [regex]::Escape($q) + "[a-zA-Z0-9_$%#@\-/\.\:]*")
        $unique = $matches | ForEach-Object { $_.Value } | Select-Object -Unique
        foreach ($u in $unique) {
            if ($u.Length -gt 3 -and $u.Length -lt 150) {
                Write-Host "  Match: $u"
            }
        }
    } else {
        Write-Host "NOT FOUND: '$q'"
    }
}
