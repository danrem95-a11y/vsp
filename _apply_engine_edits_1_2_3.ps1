$ErrorActionPreference='Stop'
$f = "C:\BTV\debug\n_cst_closing_stock.sru"
$backup = "C:\BTV\debug\n_cst_closing_stock.sru.backup_before_costing_redesign"

# ===== STEP 1: BACKUP (sudah ada dari run sebelumnya, jangan timpa) =====
if(Test-Path $backup){
    Write-Output "BACKUP sudah ada (dari run sebelumnya), tidak ditimpa: $backup"
} else {
    Copy-Item -Path $f -Destination $backup -Force
    Write-Output "BACKUP dibuat: $backup"
}

# ===== STEP 2: ENCODING SAFETY =====
$txt = [System.IO.File]::ReadAllText($f,[System.Text.Encoding]::Unicode)
$rawBytes = [System.IO.File]::ReadAllBytes($f)
$hasBOM = ($rawBytes.Length -ge 2) -and ($rawBytes[0] -eq 0xFF) -and ($rawBytes[1] -eq 0xFE)
Write-Output "BOM UTF-16LE terdeteksi di file asli: $hasBOM"

function CountOccurrences([string]$needle){
    return ([regex]::Matches($script:txt, [regex]::Escape($needle))).Count
}
function ReplaceExact([string]$old, [string]$new, [int]$expectedCount, [string]$label){
    $count = CountOccurrences $old
    Write-Output "$label -- match count: $count (expected $expectedCount)"
    if($count -ne $expectedCount){ throw "MISMATCH utk '$label': found $count, expected $expectedCount" }
    $script:txt = $script:txt.Replace($old, $new)
}

# ===== STEP 3: IMPLEMENTASI BUSINESS RULE FINAL =====

# EDIT 1: FREEZE '88' -- hapus guard immutable-forever; batas proteksi jadi rentang tanggal refresh (:ldt_tgl1/:ldt_tgl2)
$old1 = "          (TSALES1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2) AND`r`n          (ISNULL(TSALES2.HPP,0) = 0) ;"
$new1 = "          (TSALES1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2) ;"
ReplaceExact $old1 $new1 1 "EDIT1 FREEZE-88: hapus guard HPP=0, rebuild dibatasi rentang tanggal refresh"

# EDIT 2+3: step 4a (jual reguler) DAN step 4c (Adjustment) -- hapus referensi closing_avg sirkular
# (baris identik muncul 2x: sekali di helper subquery 4a, sekali di helper subquery 4c)
$old23 = "                     ISNULL( NULLIF(h.closing_avg,0), (ISNULL(h.opening_nilai,0)+ISNULL(h.beli_nilai,0)) / NULLIF(ISNULL(h.opening_qty,0)+ISNULL(h.beli_qty,0),0) ) AS HRG"
$new23 = "                     (ISNULL(h.opening_nilai,0)+ISNULL(h.beli_nilai,0)) / NULLIF(ISNULL(h.opening_qty,0)+ISNULL(h.beli_qty,0),0) AS HRG"
ReplaceExact $old23 $new23 2 "EDIT2+3 step-4a & 4c: hapus closing_avg sirkular (average dari opening+beli murni)"

# Normalisasi line ending (CRLF konsisten)
$txt = $txt -replace "`r`n", "`n"
$txt = $txt -replace "`n", "`r`n"

# ===== WRITE (UTF-16LE dgn BOM) =====
[System.IO.File]::WriteAllText($f, $txt, (New-Object System.Text.UnicodeEncoding($false,$true)))
Write-Output "DITULIS: $f"

# Verifikasi pasca-tulis
$rawAfter = [System.IO.File]::ReadAllBytes($f)
$hasBOMAfter = ($rawAfter.Length -ge 2) -and ($rawAfter[0] -eq 0xFF) -and ($rawAfter[1] -eq 0xFE)
Write-Output "BOM UTF-16LE setelah tulis: $hasBOMAfter"
$verify = [System.IO.File]::ReadAllText($f,[System.Text.Encoding]::Unicode)
Write-Output ("Verifikasi EDIT1 hilang (harus 0): " + ([regex]::Matches($verify,[regex]::Escape("(ISNULL(TSALES2.HPP,0) = 0) ;"))).Count)
Write-Output ("Verifikasi EDIT2+3 hilang (harus 0): " + ([regex]::Matches($verify,[regex]::Escape("NULLIF(h.closing_avg,0)"))).Count)
Write-Output "DONE"
