$ErrorActionPreference='Stop'
$f = "C:\BTV\debug\n_cst_closing_stock.sru"

$txt = [System.IO.File]::ReadAllText($f,[System.Text.Encoding]::Unicode)
$rawBytes = [System.IO.File]::ReadAllBytes($f)
$hasBOM = ($rawBytes.Length -ge 2) -and ($rawBytes[0] -eq 0xFF) -and ($rawBytes[1] -eq 0xFE)
Write-Output "BOM UTF-16LE terdeteksi di file (sebelum edit4): $hasBOM"

# Anchor start: SELECT tier1 -- anchor end: ')HPP' TANPA SPASI (persis seperti di source asli),
# BUKAN ') HPP' dgn spasi (itu penyebab bug kemarin -- ) HPP dgn spasi milik blok 4a yg jauh di bawah).
$startAnchor = "SELECT STOK_ID AS STOK_ID, SUM(HPP_AVG) AS HRG"
$endAnchorText = ")HPP"

$startIdx = $txt.IndexOf($startAnchor)
if($startIdx -lt 0){ throw "Start anchor tidak ditemukan" }
$endIdx = $txt.IndexOf($endAnchorText, $startIdx)
if($endIdx -lt 0){ throw "End anchor ')HPP' (tanpa spasi) tidak ditemukan setelah start" }
$endIdxFull = $endIdx + $endAnchorText.Length
$oldBlock = $txt.Substring($startIdx, $endIdxFull - $startIdx)

Write-Output "=== Blok lama (panjang $($oldBlock.Length) karakter) ==="
Write-Output $oldBlock
Write-Output "=== end blok ==="

# SANITY CHECK KERAS: blok tier1 asli seharusnya PENDEK (~120-160 karakter).
# Kalau jauh lebih panjang dari itu, anchor salah tangkap -- batalkan SEBELUM tulis apa pun.
if($oldBlock.Length -gt 250){
    throw "SANITY CHECK GAGAL: blok sepanjang $($oldBlock.Length) karakter, jauh melebihi batas wajar (250). BATALKAN -- jangan tulis apa pun."
}
if($oldBlock -notmatch "FROM SINV WHERE PERIODE" -or $oldBlock -notmatch "GROUP BY STOK_ID"){
    throw "Blok tidak sesuai isi yg diharapkan -- batalkan."
}
$countGlobal = ([regex]::Matches($txt,[regex]::Escape($startAnchor))).Count
Write-Output "Jumlah kemunculan startAnchor di seluruh file (harus 1): $countGlobal"
if($countGlobal -ne 1){ throw "startAnchor tidak unik ($countGlobal x) -- batalkan." }

$newBlock = "SELECT h.STOK_ID AS STOK_ID,`r`n                                  (ISNULL(h.opening_nilai,0)+ISNULL(h.beli_nilai,0)) / NULLIF(ISNULL(h.opening_qty,0)+ISNULL(h.beli_qty,0),0) AS HRG`r`n                                  FROM costing_helper_movavg h`r`n                )HPP"

$txt = $txt.Remove($startIdx, $endIdxFull - $startIdx).Insert($startIdx, $newBlock)
Write-Output "Blok berhasil diganti (in-memory, belum ditulis)."

$txt = $txt -replace "`r`n", "`n"
$txt = $txt -replace "`n", "`r`n"

# SANITY CHECK KEDUA: total panjang file sesudah edit harus MASUK AKAL (dekat dgn panjang asli +/- 200 char),
# bukan menyusut drastis (tanda ada blok besar terhapus tak sengaja).
$origLen = (Get-Item $f).Length
[System.IO.File]::WriteAllText($f, $txt, (New-Object System.Text.UnicodeEncoding($false,$true)))
$newLen = (Get-Item $f).Length
Write-Output "Ukuran file: sebelum=$origLen bytes, sesudah=$newLen bytes, selisih=$($newLen-$origLen) bytes"
if([Math]::Abs($newLen - $origLen) -gt 400){
    Write-Output "PERINGATAN: selisih ukuran file besar -- PERIKSA MANUAL SEKARANG."
}

$rawAfter = [System.IO.File]::ReadAllBytes($f)
$hasBOMAfter = ($rawAfter.Length -ge 2) -and ($rawAfter[0] -eq 0xFF) -and ($rawAfter[1] -eq 0xFE)
Write-Output "BOM UTF-16LE setelah tulis: $hasBOMAfter"
$verify = [System.IO.File]::ReadAllText($f,[System.Text.Encoding]::Unicode)
Write-Output ("startAnchor lama masih ada (harus 0): " + ([regex]::Matches($verify,[regex]::Escape($startAnchor))).Count)
Write-Output ("Fungsi lain masih utuh -- 'ids_view.retrieve' (harus tetap ada, >=1): " + ([regex]::Matches($verify,"ids_view.retrieve")).Count)
Write-Output ("Fungsi lain masih utuh -- 'TIER-3 FALLBACK' comment (harus tetap ada, 1): " + ([regex]::Matches($verify,"TIER-3 FALLBACK")).Count)
Write-Output "DONE"
