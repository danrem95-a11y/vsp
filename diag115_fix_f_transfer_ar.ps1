# diag115_fix_f_transfer_ar.ps1
# Refaktor f_transfer_ar(arg_voucher) di f_transfer_ar.srf - cermin patch diag114:
#  R1. Deklarasi variabel baru (file ini belum punya variabel diag112/114 sama sekali).
#  R2. Guard non-destruktif sebelum loop: jika gl_journal sudah punya baris untuk
#      voucher_manual ini -> goto keluar (create-if-missing). Di subroutine ini bahkan
#      tidak ada guard mati: ll_count dideklarasi tapi tidak pernah dipakai.
#  R3. Blok preserve sebelum DELETE, digerbang 'if ldec_actual_kas > 0':
#      - AR = uang MASUK: bank di sisi DEBET. Nilai bank aktual = sum(debet) kas_id>0.
#      - Koreksi debet/debet_kurs baris bank pertama ke nilai aktual GL lama.
#      - Salin SEMUA baris bebas (kas_id=0, doc_reff/order_reff kosong) apa adanya
#        lewat cursor: selisih kurs, biaya adm, materai, adjustment manual.

$src = 'c:\BTV\debug\f_transfer_ar.srf'
$bak = 'c:\BTV\debug\f_transfer_ar.srf.bak_diag115'
$enc = [System.Text.Encoding]::Unicode

$c = [System.IO.File]::ReadAllText($src, $enc)

if ($c.Contains('diag115')) {
    Write-Host 'SKIP: file sudah mengandung patch diag115'
    exit 0
}

Copy-Item $src $bak -Force
Write-Host "Backup: $bak"

$CRLF = "`r`n"
$T = "`t"

# Posisi awal subroutine kedua: f_transfer_ar (string arg_voucher)
$sub2 = $c.IndexOf("global subroutine f_transfer_ar (string arg_voucher);")
if ($sub2 -lt 0) { Write-Host 'MISS: subroutine arg_voucher tidak ditemukan'; exit 1 }

# -----------------------------------------------------------------------
# R1: Deklarasi setelah 'decimal ldec_kurs,ldec_bayar,...' (di subroutine kedua)
# -----------------------------------------------------------------------
$old1 = 'decimal ldec_kurs,ldec_bayar,ldec_pot,ldec_potkurs,ldec_kas,ldec_bayarreal'
$i1 = $c.IndexOf($old1, $sub2)
if ($i1 -lt 0) { Write-Host 'R1 MISS: baris deklarasi tidak ditemukan'; exit 1 }
$new1 = $old1 + $CRLF +
"decimal ldec_actual_kas, ldec_total_kas, ldec_selisih_kurs" + $CRLF +
"long k_row" + $CRLF +
"string ls_tmp_acc" + $CRLF +
"string ls_f_acc, ls_f_ket, ls_f_curr" + $CRLF +
"decimal ldec_f_debet, ldec_f_kredit, ldec_f_debetk, ldec_f_kreditk, ldec_f_rate"
$c = $c.Remove($i1, $old1.Length).Insert($i1, $new1)
Write-Host 'R1 OK: deklarasi variabel ditambahkan'

# -----------------------------------------------------------------------
# R2: Guard setelah 'if ll_ar <=0 then goto keluar;' (sebelum loop)
# -----------------------------------------------------------------------
$i2 = $c.IndexOf('if ll_ar', $sub2)
if ($i2 -lt 0) { Write-Host 'R2 MISS: baris if ll_ar tidak ditemukan'; exit 1 }
$eol = $c.IndexOf($CRLF, $i2)

$guard = $CRLF +
"//Guard diag115: jika jurnal voucher ini SUDAH ADA di GL, jangan dibangun ulang." + $CRLF +
"//Refresh hanya membuat jurnal yang hilang (create-if-missing), jurnal benar tidak disentuh." + $CRLF +
"ls_vouchermanual = lds_ar.object.voucher_manual[1]" + $CRLF +
"if isnull(ls_vouchermanual) then ls_vouchermanual = ''" + $CRLF +
"if ls_vouchermanual <> '' then" + $CRLF +
"${T}ll_count = 0" + $CRLF +
"${T}select count(*)" + $CRLF +
"${T}into :ll_count" + $CRLF +
"${T}from gl_journal" + $CRLF +
"${T}where voucher_manual = :ls_vouchermanual" + $CRLF +
"${T}using sqlca;" + $CRLF +
"${T}if isnull(ll_count) then ll_count = 0" + $CRLF +
"${T}if ll_count > 0 then goto keluar;" + $CRLF +
"end if" + $CRLF

$c = $c.Insert($eol + 2, $guard)
Write-Host 'R2 OK: guard voucher_manual ditambahkan sebelum loop'

# -----------------------------------------------------------------------
# R3: Blok preserve sebelum 'delete from gl_journal where voucher_manual'
#     (setelah re-fetch ls_vouchermanual dari tbyr1)
# -----------------------------------------------------------------------
$anchor = 'delete from gl_journal where voucher_manual = :ls_vouchermanual'
$i3 = $c.IndexOf($anchor, $sub2)
if ($i3 -lt 0) { Write-Host 'R3 MISS: anchor delete tidak ditemukan'; exit 1 }

$blk =
"//Fix diag115: pertahankan SELURUH informasi GL lama yang tidak tersimpan di tbyr2." + $CRLF +
"//AR = uang masuk: bank di sisi DEBET. Hanya berjalan jika GL lama ada (ldec_actual_kas > 0);" + $CRLF +
"//jika GL kosong (jurnal hilang yang sah dibuat ulang), tidak ada yang perlu dipertahankan." + $CRLF +
"ldec_actual_kas = 0" + $CRLF +
"select isnull(sum(debet),0)" + $CRLF +
"into :ldec_actual_kas" + $CRLF +
"from gl_journal" + $CRLF +
"where voucher_manual = :ls_vouchermanual" + $CRLF +
"  and kas_id > 0" + $CRLF +
"using sqlca;" + $CRLF +
"if isnull(ldec_actual_kas) then ldec_actual_kas = 0" + $CRLF +
"" + $CRLF +
"ldec_total_kas = 0" + $CRLF +
"for k_row = 1 to lds_update.rowcount()" + $CRLF +
"${T}ls_tmp_acc = lds_update.getitemstring(k_row,'account_id')" + $CRLF +
"${T}if isnull(ls_tmp_acc) then ls_tmp_acc = ''" + $CRLF +
"${T}if ls_tmp_acc = ls_acckas then" + $CRLF +
"${T}${T}ldec_total_kas = ldec_total_kas + lds_update.getitemdecimal(k_row,'debet')" + $CRLF +
"${T}end if" + $CRLF +
"next" + $CRLF +
"" + $CRLF +
"ldec_selisih_kurs = ldec_actual_kas - ldec_total_kas" + $CRLF +
"" + $CRLF +
"if ldec_actual_kas > 0 then" + $CRLF +
"${T}if abs(ldec_selisih_kurs) > 0.01 then" + $CRLF +
"${T}${T}//Koreksi debet bank pertama = nilai bank aktual dari GL lama" + $CRLF +
"${T}${T}for k_row = 1 to lds_update.rowcount()" + $CRLF +
"${T}${T}${T}ls_tmp_acc = lds_update.getitemstring(k_row,'account_id')" + $CRLF +
"${T}${T}${T}if isnull(ls_tmp_acc) then ls_tmp_acc = ''" + $CRLF +
"${T}${T}${T}if ls_tmp_acc = ls_acckas then" + $CRLF +
"${T}${T}${T}${T}ldec_kas = lds_update.getitemdecimal(k_row,'debet') + ldec_selisih_kurs" + $CRLF +
"${T}${T}${T}${T}lds_update.setitem(k_row,'debet',ldec_kas)" + $CRLF +
"${T}${T}${T}${T}if ldec_kurs > 0 then" + $CRLF +
"${T}${T}${T}${T}${T}lds_update.setitem(k_row,'debet_kurs',ldec_kas/ldec_kurs)" + $CRLF +
"${T}${T}${T}${T}end if" + $CRLF +
"${T}${T}${T}${T}exit" + $CRLF +
"${T}${T}${T}end if" + $CRLF +
"${T}${T}next" + $CRLF +
"${T}end if" + $CRLF +
"${T}//Salin SEMUA baris bebas GL lama apa adanya (kas_id=0, doc_reff/order_reff kosong):" + $CRLF +
"${T}//selisih kurs, biaya adm, materai, adjustment manual. Tanpa TOP 1 / SUM / heuristik akun." + $CRLF +
"${T}declare cur_free_ar cursor for" + $CRLF +
"${T}select account_id, isnull(ket,''), isnull(debet,0), isnull(kredit,0)," + $CRLF +
"${T}${T}isnull(debet_kurs,0), isnull(kredit_kurs,0), isnull(curr_id,'IDR'), isnull(rate_rp,0)" + $CRLF +
"${T}from gl_journal" + $CRLF +
"${T}where voucher_manual = :ls_vouchermanual" + $CRLF +
"${T}  and isnull(kas_id,0) = 0" + $CRLF +
"${T}  and isnull(doc_reff,'') = ''" + $CRLF +
"${T}  and isnull(order_reff,'') = '';" + $CRLF +
"${T}open cur_free_ar;" + $CRLF +
"${T}fetch cur_free_ar into :ls_f_acc, :ls_f_ket, :ldec_f_debet, :ldec_f_kredit, :ldec_f_debetk, :ldec_f_kreditk, :ls_f_curr, :ldec_f_rate;" + $CRLF +
"${T}do while sqlca.sqlcode = 0" + $CRLF +
"${T}${T}lds_update.setrow(lds_update.insertrow(0))" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'voucher',ls_voucher)" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'urut',lds_update.getrow())" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'tgl',ldt_tgl)" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'modul_id','CI')" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'site_id',gs_site)" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'posting','P')" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'kas_id',0)" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'account_id',ls_f_acc)" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'ket',ls_f_ket)" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'debet',ldec_f_debet)" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'kredit',ldec_f_kredit)" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'debet_kurs',ldec_f_debetk)" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'kredit_kurs',ldec_f_kreditk)" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'curr_id',ls_f_curr)" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'rate_rp',ldec_f_rate)" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'voucher_manual',ls_vouchermanual)" + $CRLF +
"${T}${T}//doc_reff/order_reff sengaja kosong, sama seperti baris asalnya" + $CRLF +
"${T}${T}fetch cur_free_ar into :ls_f_acc, :ls_f_ket, :ldec_f_debet, :ldec_f_kredit, :ldec_f_debetk, :ldec_f_kreditk, :ls_f_curr, :ldec_f_rate;" + $CRLF +
"${T}loop" + $CRLF +
"${T}close cur_free_ar;" + $CRLF +
"end if" + $CRLF +
"" + $CRLF

$c = $c.Insert($i3, $blk)
Write-Host 'R3 OK: blok preserve disisipkan sebelum delete'

[System.IO.File]::WriteAllText($src, $c, $enc)
Write-Host "Ditulis: $src"

# -----------------------------------------------------------------------
# Verifikasi
# -----------------------------------------------------------------------
$v = [System.IO.File]::ReadAllText($src, $enc)
Write-Host ''
Write-Host '=== Verifikasi token ==='
foreach ($tk in @(
    'Guard diag115',
    'Fix diag115',
    'if ll_count > 0 then goto keluar;',
    'isnull(sum(debet),0)',
    'declare cur_free_ar cursor for',
    'open cur_free_ar;',
    'close cur_free_ar;',
    'do while sqlca.sqlcode = 0',
    'if ldec_actual_kas > 0 then',
    "setitem(k_row,'debet',ldec_kas)"
)) {
    if ($v.Contains($tk)) { Write-Host "  FOUND: $tk" } else { Write-Host "  MISSING: $tk" }
}
# Pastikan urutan: guard < loop 'for i = 1 to ll_ar' < preserve < delete (dalam subroutine kedua)
$p0 = $v.IndexOf('Guard diag115')
$p1 = $v.IndexOf('for i = 1 to ll_ar')
$p2 = $v.IndexOf('Fix diag115')
$p3 = $v.IndexOf('delete from gl_journal where voucher_manual = :ls_vouchermanual')
Write-Host ''
if ($p0 -lt $p1 -and $p1 -lt $p2 -and $p2 -lt $p3) {
    Write-Host "URUTAN OK: guard($p0) < loop($p1) < preserve($p2) < delete($p3)"
} else {
    Write-Host "URUTAN SALAH: guard=$p0 loop=$p1 preserve=$p2 delete=$p3"
}
