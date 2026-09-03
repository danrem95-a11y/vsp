$ErrorActionPreference='Stop'
$f = "C:\BTV\debug\w_refresh_journal.srw"

$txt = [System.IO.File]::ReadAllText($f,[System.Text.Encoding]::Unicode)
$rawBytes = [System.IO.File]::ReadAllBytes($f)
$hasBOM = ($rawBytes.Length -ge 2) -and ($rawBytes[0] -eq 0xFF) -and ($rawBytes[1] -eq 0xFE)
Write-Output "BOM UTF-16LE sebelum: $hasBOM"

$startAnchor = "event open;call super::open"
$endAnchor = "end event"
$startIdx = $txt.IndexOf($startAnchor)
if($startIdx -lt 0){ throw "event open lama tidak ditemukan -- apakah sudah pernah dipasang?" }
$endIdx = $txt.IndexOf($endAnchor, $startIdx)
if($endIdx -lt 0){ throw "end event tidak ditemukan" }
$endIdxFull = $endIdx + $endAnchor.Length
$oldBlock = $txt.Substring($startIdx, $endIdxFull - $startIdx)
Write-Output "=== Blok event open LAMA (panjang $($oldBlock.Length)) ==="
Write-Output $oldBlock
if($oldBlock.Length -gt 700){ throw "SANITY: blok terlalu panjang, batalkan." }
if($oldBlock -notmatch "close\(this\)"){ throw "Blok tidak sesuai ekspektasi -- batalkan." }

$countGlobal = ([regex]::Matches($txt,[regex]::Escape($startAnchor))).Count
Write-Output "Jumlah kemunculan startAnchor (harus 1): $countGlobal"
if($countGlobal -ne 1){ throw "tidak unik, batalkan" }

$line1 = "Menu Refresh Journal (versi lama) sudah dipindahkan ke Refresh Transaksi Modern.~r~n"
$line2 = "Window ini akan otomatis mengarahkan Anda ke sana."
$msg = $line1 + $line2

$newBlock = "event open;call super::open`r`nmessagebox('Refresh Journal Dipindahkan', '" + $msg + "', Information!)`r`nOpen(w_refresh_transaksi_modern)`r`nclose(this)`r`nend event"

$txt = $txt.Remove($startIdx, $endIdxFull - $startIdx).Insert($startIdx, $newBlock)
Write-Output "Blok event open berhasil di-upgrade jadi auto-redirect (in-memory)."

$txt = $txt -replace "`r`n", "`n"
$txt = $txt -replace "`n", "`r`n"

$origLen = (Get-Item $f).Length
[System.IO.File]::WriteAllText($f, $txt, (New-Object System.Text.UnicodeEncoding($false,$true)))
$newLen = (Get-Item $f).Length
Write-Output "Ukuran file: sebelum=$origLen sesudah=$newLen selisih=$($newLen-$origLen)"

$rawAfter = [System.IO.File]::ReadAllBytes($f)
$hasBOMAfter = ($rawAfter.Length -ge 2) -and ($rawAfter[0] -eq 0xFF) -and ($rawAfter[1] -eq 0xFE)
Write-Output "BOM UTF-16LE sesudah: $hasBOMAfter"
$verify = [System.IO.File]::ReadAllText($f,[System.Text.Encoding]::Unicode)
Write-Output ("'Open(w_refresh_transaksi_modern)' terdeteksi (harus 1): " + ([regex]::Matches($verify,[regex]::Escape("Open(w_refresh_transaksi_modern)"))).Count)
Write-Output ("'on w_refresh_journal.destroy' masih ada (harus 1): " + ([regex]::Matches($verify,[regex]::Escape("on w_refresh_journal.destroy"))).Count)
Write-Output "DONE"
