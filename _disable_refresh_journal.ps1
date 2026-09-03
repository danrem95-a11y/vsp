$ErrorActionPreference='Stop'
$f = "C:\BTV\debug\w_refresh_journal.srw"
$backup = "C:\BTV\debug\w_refresh_journal.srw.backup_before_disable"

# ===== BACKUP =====
if(Test-Path $backup){
    Write-Output "BACKUP sudah ada, tidak ditimpa: $backup"
} else {
    Copy-Item -Path $f -Destination $backup -Force
    Write-Output "BACKUP dibuat: $backup"
}

$txt = [System.IO.File]::ReadAllText($f,[System.Text.Encoding]::Unicode)
$rawBytes = [System.IO.File]::ReadAllBytes($f)
$hasBOM = ($rawBytes.Length -ge 2) -and ($rawBytes[0] -eq 0xFF) -and ($rawBytes[1] -eq 0xFE)
Write-Output "BOM UTF-16LE sebelum: $hasBOM"

# Anchor: sisipkan event open BARU tepat SETELAH 'end on' penutup 'on w_refresh_journal.create'
# dan SEBELUM 'on w_refresh_journal.destroy'.
$anchorEnd = "end on`r`n`r`non w_refresh_journal.destroy"
$idx = $txt.IndexOf($anchorEnd)
if($idx -lt 0){ throw "Anchor 'end on ... on w_refresh_journal.destroy' tidak ditemukan" }
$countAnchor = ([regex]::Matches($txt,[regex]::Escape($anchorEnd))).Count
Write-Output "Jumlah kemunculan anchor (harus 1): $countAnchor"
if($countAnchor -ne 1){ throw "Anchor tidak unik -- batalkan." }

# String pesan PowerBuilder pakai single-quote (bukan double-quote) supaya tidak perlu nested-escape.
# ~r~n adalah escape newline milik PowerBuilder sendiri (bukan PowerShell), ditulis literal apa adanya.
$line1 = "Window REFRESH JOURNAL (versi lama) sudah DINONAKTIFKAN dan tidak boleh dipakai lagi.~r~n"
$line2 = "Semua proses refresh transaksi dan journal WAJIB memakai Refresh Transaksi Modern.~r~n~r~n"
$line3 = "Window ini akan tertutup otomatis."
$msg = $line1 + $line2 + $line3

$newEventBlock = "end on`r`n`r`nevent open;call super::open`r`nmessagebox('Refresh Journal Dinonaktifkan', '" + $msg + "', Exclamation!)`r`nclose(this)`r`nend event`r`n`r`non w_refresh_journal.destroy"

$textBefore = $txt.Substring(0, $idx)
$textAfter = $txt.Substring($idx + $anchorEnd.Length)
$txt = $textBefore + $newEventBlock + $textAfter
Write-Output "Blok event open baru berhasil disisipkan (in-memory)."

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
Write-Output ("event open baru terdeteksi (harus 1): " + ([regex]::Matches($verify,[regex]::Escape("event open;call super::open"))).Count)
Write-Output ("'on w_refresh_journal.destroy' masih ada (harus 1): " + ([regex]::Matches($verify,[regex]::Escape("on w_refresh_journal.destroy"))).Count)
Write-Output "DONE"
