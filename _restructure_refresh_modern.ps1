$ErrorActionPreference='Stop'
$f = "C:\BTV\debug\w_refresh_transaksi_modern.srw"
$backup = "C:\BTV\debug\w_refresh_transaksi_modern.srw.backup_before_costing_redesign"

# ===== STEP 1: BACKUP =====
if(Test-Path $backup){
    Write-Output "BACKUP sudah ada, tidak ditimpa: $backup"
} else {
    Copy-Item -Path $f -Destination $backup -Force
    Write-Output "BACKUP dibuat: $backup"
}

# ===== STEP 2: ENCODING SAFETY =====
$txt = [System.IO.File]::ReadAllText($f,[System.Text.Encoding]::Unicode)
$rawBytes = [System.IO.File]::ReadAllBytes($f)
$hasBOM = ($rawBytes.Length -ge 2) -and ($rawBytes[0] -eq 0xFF) -and ($rawBytes[1] -eq 0xFE)
Write-Output "BOM UTF-16LE terdeteksi di file asli: $hasBOM"

# ===== STEP 3a: Ekstrak blok costing engine dari dalam of_refresh_so() (anchor-based, hindari salah ketik whitespace) =====
$startAnchor = "//2. Update HPP Average ke tsales2"
$endAnchor = "//3. Re-transfer SO DAN HPP"
$startIdx = $txt.IndexOf($startAnchor)
$endIdx = $txt.IndexOf($endAnchor)
if($startIdx -lt 0 -or $endIdx -lt 0 -or $endIdx -le $startIdx){ throw "Anchor tidak ditemukan / urutan salah. startIdx=$startIdx endIdx=$endIdx" }
$blockToRemove = $txt.Substring($startIdx, $endIdx - $startIdx)
Write-Output "=== Blok yang akan dihapus dari of_refresh_so() (panjang $($blockToRemove.Length) karakter) ==="
Write-Output $blockToRemove
Write-Output "=== end blok ==="

# Verifikasi blok mengandung pemanggilan closing engine yg diharapkan
if($blockToRemove -notmatch "n_cst_closing_stock" -or $blockToRemove -notmatch "lnv_close.of_run"){
    throw "Blok yang diekstrak tidak mengandung pemanggilan n_cst_closing_stock yg diharapkan -- batalkan demi keamanan."
}

# ===== STEP 3b: Hapus blok dari of_refresh_so(), sisakan hanya baris kosong penghubung =====
$txt = $txt.Remove($startIdx, $endIdx - $startIdx)
Write-Output "Blok berhasil dihapus dari of_refresh_so()."

# ===== STEP 3c: Susun blok baru utk level TOP (selalu jalan, tidak tergantung checkbox) =====
$newTopBlock = @"
// === WAJIB: Costing Engine (HPP Average + rebuild WIP-Out bulan yg direfresh) SELALU
//     jalan LEBIH DULU, TIDAK bergantung checkbox modul mana yg dicentang (business rule final:
//     refresh bulan X = historical rebuild bulan X, terlepas dari modul transaksi yg diproses).
st_1.text = 'Update HPP Average...'
setpointer(hourglass!)
n_cst_closing_stock lnv_close_top
integer li_closerc_top
lnv_close_top = create n_cst_closing_stock
st_2.text = 'Closing stok: mengambil data (retrieve)...'
yield()
li_closerc_top = lnv_close_top.of_run(f_bom(datetime(ld1)), false, false, 1, 0, st_2)
destroy lnv_close_top
if li_closerc_top <> 1 then
	messagebox('Closing Stok','Proses closing stok GAGAL. Refresh dihentikan.',StopSign!)
	if ll_refresh_id > 0 then
		update refresh_ledger set ts_end = current timestamp, status = 'ERROR' where refresh_id = :ll_refresh_id using sqlca;
		commit using sqlca;
	end if
	this.text = '?  MULAI REFRESH'
	ib_running = false
	setpointer(arrow!)
	return
end if
st_1.text = ''

"@

# ===== STEP 3d: Sisipkan blok baru SEBELUM dispatch checkbox modul =====
$insertAnchor = "if cb_so.checked then of_run_modul('SO')"
$insertIdx = $txt.IndexOf($insertAnchor)
if($insertIdx -lt 0){ throw "Insert anchor tidak ditemukan setelah penghapusan blok lama." }
$txt = $txt.Insert($insertIdx, $newTopBlock)
Write-Output "Blok costing baru disisipkan sebelum dispatch checkbox modul."

# Normalisasi line ending
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
Write-Output ("n_cst_closing_stock muncul (harus 2x: definisi lnv_close_top di top-level + tetap ada di function lain kalau ada): " + ([regex]::Matches($verify,"n_cst_closing_stock")).Count)
Write-Output ("of_run( muncul (harus tetap ada, minimal di top-level + sync-WIP-in): " + ([regex]::Matches($verify,"\.of_run\(")).Count)
Write-Output "DONE"
