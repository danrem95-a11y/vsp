# diag114_fix_f_transfer_ap.ps1
# Perbaikan f_transfer_ap.srf sesuai review:
#  R1. Guard non-destruktif paling awal (sebelum loop): jika gl_journal sudah punya baris
#      untuk voucher_manual ini -> goto keluar. Mengembalikan perilaku aman versi original
#      (refresh = create-if-missing). Guard lama 'if ll_count > 0' mati karena ll_count
#      tidak pernah diisi (typo/copy-paste error).
#  R2. Deklarasi variabel baru untuk penyalinan baris bebas.
#  R3. Ganti blok diag112 (TOP 1 + sintesis 1 baris selisih agregat) dengan:
#      - koreksi kredit bank = nilai bank aktual GL lama (tetap)
#      - salin SEMUA baris bebas (kas_id=0, doc_reff/order_reff kosong) apa adanya
#        lewat cursor: selisih kurs, biaya adm, materai, adjustment manual, dll.
#      Seluruh blok digerbang 'if ldec_actual_kas > 0' supaya tidak melakukan apa pun
#      saat GL lama memang tidak ada (kasus CN/DN/Adj hilang yang sah untuk rebuild).

$src = 'c:\BTV\debug\f_transfer_ap.srf'
$bak = 'c:\BTV\debug\f_transfer_ap.srf.bak_diag114'
$enc = [System.Text.Encoding]::Unicode

$c = [System.IO.File]::ReadAllText($src, $enc)

if ($c.Contains('diag114')) {
    Write-Host 'SKIP: file sudah mengandung patch diag114'
    exit 0
}

Copy-Item $src $bak -Force
Write-Host "Backup: $bak"

$CRLF = "`r`n"
$T = "`t"

# -----------------------------------------------------------------------
# R1: Guard setelah 'if ll_ar <=0 then goto keluar;' (sebelum loop faktur)
# -----------------------------------------------------------------------
$i = $c.IndexOf('if ll_ar')
if ($i -lt 0) { Write-Host 'R1 MISS: baris if ll_ar tidak ditemukan'; exit 1 }
$eol = $c.IndexOf($CRLF, $i)

$guard = $CRLF +
"//Guard diag114: jika jurnal voucher ini SUDAH ADA di GL, jangan dibangun ulang." + $CRLF +
"//Mengembalikan perilaku aman versi original (refresh hanya membuat jurnal yang hilang)." + $CRLF +
"//Guard lama 'if ll_count > 0' tidak pernah aktif karena ll_count tidak pernah diisi." + $CRLF +
"ls_vouchermanual = lds_ap.object.voucher_manual[1]" + $CRLF +
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
Write-Host 'R1 OK: guard voucher_manual ditambahkan sebelum loop'

# -----------------------------------------------------------------------
# R2: Deklarasi variabel baru setelah 'string ls_tmp_acc'
# -----------------------------------------------------------------------
$old2 = 'string ls_tmp_acc'
$new2 = "string ls_tmp_acc" + $CRLF +
"string ls_f_acc, ls_f_ket, ls_f_curr" + $CRLF +
"decimal ldec_f_debet, ldec_f_kredit, ldec_f_debetk, ldec_f_kreditk, ldec_f_rate"

$idx2 = $c.IndexOf($old2)
$idx2b = $c.IndexOf($old2, $idx2 + 1)
if ($idx2 -lt 0) { Write-Host 'R2 MISS: deklarasi ls_tmp_acc tidak ditemukan'; exit 1 }
if ($idx2b -ge 0) { Write-Host 'R2 WARN: ls_tmp_acc muncul lebih dari sekali, pakai yang pertama' }
$c = $c.Remove($idx2, $old2.Length).Insert($idx2, $new2)
Write-Host 'R2 OK: deklarasi variabel penyalinan ditambahkan'

# -----------------------------------------------------------------------
# R3: Ganti blok 'if abs(ldec_selisih_kurs) > 0.01 then ... end if' (diag112)
#     sampai sebelum '//Delete data GL before Update'
# -----------------------------------------------------------------------
$a = $c.IndexOf('if abs(ldec_selisih_kurs) > 0.01 then')
$b = $c.IndexOf('//Delete data GL before Update', [Math]::Max($a,0))
if ($a -lt 0 -or $b -lt 0 -or $a -ge $b) { Write-Host "R3 MISS: anchor tidak ditemukan (a=$a b=$b)"; exit 1 }

$new3 =
"//Fix diag114: pertahankan SELURUH informasi GL lama yang tidak tersimpan di tbyr2." + $CRLF +
"//Hanya berjalan jika GL lama memang ada (ldec_actual_kas > 0); jika GL kosong" + $CRLF +
"//(kasus CN/DN/Adj hilang), tidak ada yang perlu dipertahankan." + $CRLF +
"if ldec_actual_kas > 0 then" + $CRLF +
"${T}if abs(ldec_selisih_kurs) > 0.01 then" + $CRLF +
"${T}${T}//Koreksi kredit bank pertama = nilai bank aktual dari GL lama" + $CRLF +
"${T}${T}for k_row = 1 to lds_update.rowcount()" + $CRLF +
"${T}${T}${T}ls_tmp_acc = lds_update.getitemstring(k_row,'account_id')" + $CRLF +
"${T}${T}${T}if isnull(ls_tmp_acc) then ls_tmp_acc = ''" + $CRLF +
"${T}${T}${T}if ls_tmp_acc = ls_acckas then" + $CRLF +
"${T}${T}${T}${T}ldec_kas = lds_update.getitemdecimal(k_row,'kredit') + ldec_selisih_kurs" + $CRLF +
"${T}${T}${T}${T}lds_update.setitem(k_row,'kredit',ldec_kas)" + $CRLF +
"${T}${T}${T}${T}if ldec_kurs > 0 then" + $CRLF +
"${T}${T}${T}${T}${T}lds_update.setitem(k_row,'kredit_kurs',ldec_kas/ldec_kurs)" + $CRLF +
"${T}${T}${T}${T}end if" + $CRLF +
"${T}${T}${T}${T}exit" + $CRLF +
"${T}${T}${T}end if" + $CRLF +
"${T}${T}next" + $CRLF +
"${T}end if" + $CRLF +
"${T}//Salin SEMUA baris bebas GL lama apa adanya (kas_id=0, doc_reff/order_reff kosong):" + $CRLF +
"${T}//selisih kurs, biaya adm, materai, adjustment manual. Tanpa TOP 1 / SUM / heuristik akun" + $CRLF +
"${T}//sehingga tidak ada salah klasifikasi dan struktur jurnal lama dipertahankan." + $CRLF +
"${T}declare cur_free cursor for" + $CRLF +
"${T}select account_id, isnull(ket,''), isnull(debet,0), isnull(kredit,0)," + $CRLF +
"${T}${T}isnull(debet_kurs,0), isnull(kredit_kurs,0), isnull(curr_id,'IDR'), isnull(rate_rp,0)" + $CRLF +
"${T}from gl_journal" + $CRLF +
"${T}where voucher_manual = :ls_vouchermanual" + $CRLF +
"${T}  and isnull(kas_id,0) = 0" + $CRLF +
"${T}  and isnull(doc_reff,'') = ''" + $CRLF +
"${T}  and isnull(order_reff,'') = '';" + $CRLF +
"${T}open cur_free;" + $CRLF +
"${T}fetch cur_free into :ls_f_acc, :ls_f_ket, :ldec_f_debet, :ldec_f_kredit, :ldec_f_debetk, :ldec_f_kreditk, :ls_f_curr, :ldec_f_rate;" + $CRLF +
"${T}do while sqlca.sqlcode = 0" + $CRLF +
"${T}${T}lds_update.setrow(lds_update.insertrow(0))" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'voucher',ls_voucher)" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'urut',lds_update.getrow())" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'tgl',ldt_tgl)" + $CRLF +
"${T}${T}lds_update.setitem(lds_update.getrow(),'modul_id','CO')" + $CRLF +
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
"${T}${T}fetch cur_free into :ls_f_acc, :ls_f_ket, :ldec_f_debet, :ldec_f_kredit, :ldec_f_debetk, :ldec_f_kreditk, :ls_f_curr, :ldec_f_rate;" + $CRLF +
"${T}loop" + $CRLF +
"${T}close cur_free;" + $CRLF +
"end if" + $CRLF

$c = $c.Remove($a, $b - $a).Insert($a, $new3)
Write-Host 'R3 OK: blok TOP1/agregat diganti dengan salin-semua-baris-bebas (cursor)'

[System.IO.File]::WriteAllText($src, $c, $enc)
Write-Host "Ditulis: $src"

# -----------------------------------------------------------------------
# Verifikasi
# -----------------------------------------------------------------------
$v = [System.IO.File]::ReadAllText($src, $enc)
$tokens = @(
    'Guard diag114',
    'select count(*)',
    'if ll_count > 0 then goto keluar;',
    'declare cur_free cursor for',
    'open cur_free;',
    'close cur_free;',
    'do while sqlca.sqlcode = 0',
    'if ldec_actual_kas > 0 then'
)
Write-Host ''
Write-Host '=== Verifikasi token ==='
foreach ($tk in $tokens) {
    if ($v.Contains($tk)) { Write-Host "  FOUND: $tk" } else { Write-Host "  MISSING: $tk" }
}
Write-Host ''
Write-Host '=== Token lama yang harus hilang ==='
foreach ($tk in @('select top 1 account_id','ls_selisih_acc <> ''''','Rugi kurs','Laba kurs')) {
    if ($v.Contains($tk)) { Write-Host "  MASIH ADA: $tk" } else { Write-Host "  HILANG (OK): $tk" }
}
