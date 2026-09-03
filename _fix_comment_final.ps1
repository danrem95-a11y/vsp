$ErrorActionPreference='Stop'
$f = "C:\BTV\debug\n_cst_closing_stock.sru"
$txt = [System.IO.File]::ReadAllText($f,[System.Text.Encoding]::Unicode)

$startAnchor = "FREEZE '88' (WIP-Out) $([char]8212) IMMUTABLE tanpa tabel."
$endAnchor = "NON-SIRKULAR & idempotent."
$startIdx = $txt.IndexOf($startAnchor)
if($startIdx -lt 0){ throw "start anchor tidak ketemu" }
$endIdx = $txt.IndexOf($endAnchor, $startIdx)
if($endIdx -lt 0){ throw "end anchor tidak ketemu" }
$endIdxFull = $endIdx + $endAnchor.Length
$oldComment = $txt.Substring($startIdx, $endIdxFull - $startIdx)
Write-Output "=== komentar lama (panjang $($oldComment.Length)) ==="
Write-Output $oldComment
if($oldComment.Length -gt 400){ throw "SANITY: komentar terlalu panjang ($($oldComment.Length)), batalkan." }

$newComment = "FREEZE '88' (WIP-Out) $([char]8212) IMMUTABLE PER-PERIODE ASAL. Refresh bulan X = historical`r`n//     rebuild bulan X: HANYA WIP-Out ber-TGL dalam rentang :ldt_tgl1-:ldt_tgl2 yg dihitung ulang`r`n//     (proteksi = periode asal transaksi, BUKAN status HPP=0/<>0). WIP-Out bulan LAIN yg tidak`r`n//     direfresh TIDAK tersentuh sama sekali -- immutable tetap berlaku selama bulan asalnya tidak`r`n//     diminta refresh ulang. Nilai = opening+beli+koreksi bulan berjalan (costing_helper_movavg)`r`n//     dgn fallback WIP-In (tstok88 coa_id). NON-SIRKULAR."

$count = ([regex]::Matches($txt,[regex]::Escape($oldComment))).Count
Write-Output "match count global: $count"
if($count -ne 1){ throw "tidak unik, batalkan" }
$txt = $txt.Replace($oldComment,$newComment)
$txt = $txt -replace "`r`n","`n"
$txt = $txt -replace "`n","`r`n"

$origLen = (Get-Item $f).Length
[System.IO.File]::WriteAllText($f,$txt,(New-Object System.Text.UnicodeEncoding($false,$true)))
$newLen = (Get-Item $f).Length
Write-Output "Ukuran: sebelum=$origLen sesudah=$newLen selisih=$($newLen-$origLen)"
if([Math]::Abs($newLen-$origLen) -gt 400){ Write-Output "PERINGATAN selisih besar -- periksa manual" }
$rawAfter = [System.IO.File]::ReadAllBytes($f)
Write-Output ("BOM sesudah: " + (($rawAfter[0] -eq 0xFF) -and ($rawAfter[1] -eq 0xFE)))
Write-Output "DONE"
