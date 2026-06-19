# diag112_fix_selisih_kurs.ps1
# Fix f_transfer_ap.srf - Preserve Selisih Kurs (exchange rate difference) row
# when Refresh Journal rebuilds the GL journal.
#
# Root cause:
#   f_transfer_ap computes bank (BCA) kredit = nilai_hutang - potongan.
#   When there is a foreign-currency payment, the actual bank amount includes
#   a selisih kurs (exchange rate difference). This is in the existing GL journal
#   but NOT stored in tbyr2.nilai_potidr.  After refresh, the selisih kurs row
#   disappears and the bank amount is wrong.
#
# Fix strategy:
#   After the invoice loop (but BEFORE deleting the GL), read the actual bank
#   amount from the existing GL.  If it differs from the computed total, find the
#   selisih kurs account (account with kas_id=0, empty doc_reff/order_reff) and:
#     1. Adjust the first BCA kredit row in lds_update to the actual bank amount.
#     2. Add a selisih kurs debet/kredit row for the difference.
#
#   This is safe for IDR payments (selisih = 0, no change).
#   Works on every subsequent refresh because the correct GL is preserved.

$srcFile = "c:\BTV\debug\f_transfer_ap.srf"
$bakFile = "c:\BTV\debug\f_transfer_ap.srf.bak_diag112"

$enc = [System.Text.Encoding]::Unicode
$content = [System.IO.File]::ReadAllText($srcFile, $enc)

Copy-Item $srcFile $bakFile -Force
Write-Host "Backup: $bakFile"

# -----------------------------------------------------------------------
# R1: Add new variable declarations after the existing decimal declaration
#     on line 341:  "decimal ldec_kurs,ldec_bayar,ldec_pot,ldec_potkurs,ldec_kas,ldec_bayarreal"
# -----------------------------------------------------------------------
$T = "`t"   # TAB character

$old1 = "decimal ldec_kurs,ldec_bayar,ldec_pot,ldec_potkurs,ldec_kas,ldec_bayarreal"
$new1 = "decimal ldec_kurs,ldec_bayar,ldec_pot,ldec_potkurs,ldec_kas,ldec_bayarreal`r`ndecimal ldec_actual_kas, ldec_total_kas, ldec_selisih_kurs`r`nstring ls_selisih_acc, ls_selisih_ket`r`nlong k_row`r`nstring ls_tmp_acc"

if ($content.Contains($old1)) {
    $content = $content.Replace($old1, $new1)
    Write-Host "R1 OK: Added selisih kurs variable declarations"
} else {
    Write-Host "R1 MISS: Declaration line not found"
}

# -----------------------------------------------------------------------
# R2: Insert the selisih kurs fix block after "next" (end of invoice loop)
#     and before "//Delete data GL before Update"
# -----------------------------------------------------------------------

# New code block to insert (uses TAB indentation matching the .srf style)
$fix = @"

//Fix diag112: Preserve selisih kurs dari GL yang ada (sebelum dihapus)
//   Baca nilai bank aktual dari GL, koreksi kredit BCA, tambah baris selisih kurs
ldec_actual_kas = 0
select isnull(sum(kredit),0)
into :ldec_actual_kas
from gl_journal
where voucher_manual = :ls_vouchermanual
  and kas_id > 0
using sqlca;
if isnull(ldec_actual_kas) then ldec_actual_kas = 0

ldec_total_kas = 0
for k_row = 1 to lds_update.rowcount()
${T}ls_tmp_acc = lds_update.getitemstring(k_row,'account_id')
${T}if isnull(ls_tmp_acc) then ls_tmp_acc = ''
${T}if ls_tmp_acc = ls_acckas then
${T}${T}ldec_total_kas = ldec_total_kas + lds_update.getitemdecimal(k_row,'kredit')
${T}end if
next

ldec_selisih_kurs = ldec_actual_kas - ldec_total_kas

if abs(ldec_selisih_kurs) > 0.01 then
${T}ls_selisih_acc = ''
${T}ls_selisih_ket = ''
${T}select top 1 account_id, isnull(ket,'')
${T}into :ls_selisih_acc, :ls_selisih_ket
${T}from gl_journal
${T}where voucher_manual = :ls_vouchermanual
${T}  and kas_id = 0
${T}  and isnull(doc_reff,'') = ''
${T}  and isnull(order_reff,'') = ''
${T}using sqlca;
${T}if isnull(ls_selisih_acc) then ls_selisih_acc = ''
${T}if isnull(ls_selisih_ket) then ls_selisih_ket = ''
${T}if ls_selisih_acc <> '' then
${T}${T}//Koreksi kredit BCA pertama: sesuaikan dengan selisih kurs
${T}${T}for k_row = 1 to lds_update.rowcount()
${T}${T}${T}ls_tmp_acc = lds_update.getitemstring(k_row,'account_id')
${T}${T}${T}if isnull(ls_tmp_acc) then ls_tmp_acc = ''
${T}${T}${T}if ls_tmp_acc = ls_acckas then
${T}${T}${T}${T}ldec_kas = lds_update.getitemdecimal(k_row,'kredit') + ldec_selisih_kurs
${T}${T}${T}${T}lds_update.setitem(k_row,'kredit',ldec_kas)
${T}${T}${T}${T}if ldec_kurs > 0 then
${T}${T}${T}${T}${T}lds_update.setitem(k_row,'kredit_kurs',ldec_kas/ldec_kurs)
${T}${T}${T}${T}end if
${T}${T}${T}${T}exit
${T}${T}${T}end if
${T}${T}next
${T}${T}//Tambah baris selisih kurs (debet jika rugi kurs, kredit jika laba kurs)
${T}${T}lds_update.setrow(lds_update.insertrow(0))
${T}${T}lds_update.setitem(lds_update.getrow(),'voucher',ls_voucher)
${T}${T}lds_update.setitem(lds_update.getrow(),'urut',lds_update.getrow())
${T}${T}lds_update.setitem(lds_update.getrow(),'tgl',ldt_tgl)
${T}${T}lds_update.setitem(lds_update.getrow(),'modul_id','CO')
${T}${T}lds_update.setitem(lds_update.getrow(),'site_id',gs_site)
${T}${T}lds_update.setitem(lds_update.getrow(),'posting','P')
${T}${T}lds_update.setitem(lds_update.getrow(),'kas_id',0)
${T}${T}lds_update.setitem(lds_update.getrow(),'account_id',ls_selisih_acc)
${T}${T}lds_update.setitem(lds_update.getrow(),'ket',ls_selisih_ket)
${T}${T}if ldec_selisih_kurs > 0 then //Rugi kurs: bank bayar lebih dari hutang
${T}${T}${T}lds_update.setitem(lds_update.getrow(),'debet',ldec_selisih_kurs)
${T}${T}${T}lds_update.setitem(lds_update.getrow(),'kredit',0.00)
${T}${T}${T}lds_update.setitem(lds_update.getrow(),'kredit_kurs',0.00)
${T}${T}${T}if ldec_kurs > 0 then
${T}${T}${T}${T}lds_update.setitem(lds_update.getrow(),'debet_kurs',ldec_selisih_kurs/ldec_kurs)
${T}${T}${T}end if
${T}${T}else //Laba kurs: bank bayar kurang dari hutang
${T}${T}${T}lds_update.setitem(lds_update.getrow(),'kredit',abs(ldec_selisih_kurs))
${T}${T}${T}lds_update.setitem(lds_update.getrow(),'debet',0.00)
${T}${T}${T}lds_update.setitem(lds_update.getrow(),'debet_kurs',0.00)
${T}${T}${T}if ldec_kurs > 0 then
${T}${T}${T}${T}lds_update.setitem(lds_update.getrow(),'kredit_kurs',abs(ldec_selisih_kurs)/ldec_kurs)
${T}${T}${T}end if
${T}${T}end if
${T}${T}lds_update.setitem(lds_update.getrow(),'curr_id',ls_curr)
${T}${T}lds_update.setitem(lds_update.getrow(),'rate_rp',ldec_kurs)
${T}${T}lds_update.setitem(lds_update.getrow(),'voucher_manual',ls_vouchermanual)
${T}${T}//doc_reff sengaja kosong: menandai baris selisih kurs (bukan AP invoice row)
${T}end if
end if

"@

$old2 = "next`r`n//Delete data GL before Update`r`ndelete from gl_journal where voucher_manual = :ls_vouchermanual using sqlca; commit;"
$new2 = "next" + $fix + "//Delete data GL before Update`r`ndelete from gl_journal where voucher_manual = :ls_vouchermanual using sqlca; commit;"

if ($content.Contains($old2)) {
    $content = $content.Replace($old2, $new2)
    Write-Host "R2 OK: Inserted selisih kurs fix block after invoice loop"
} else {
    Write-Host "R2 MISS: next + delete pattern not found"
    # Try alternate CRLF
    $old2b = "next`r`n//Delete data GL before Update"
    Write-Host "  Contains 'next CRLF //Delete': $($content.Contains($old2b))"
}

# Write result
[System.IO.File]::WriteAllText($srcFile, $content, $enc)
Write-Host "`nDone. Written: $srcFile"

# Verify
$verify = [System.IO.File]::ReadAllText($srcFile, $enc)
$hits = @(
    "ldec_actual_kas",
    "ldec_selisih_kurs",
    "ls_selisih_acc",
    "isnull(sum(kredit),0)",
    "ls_tmp_acc = ls_acckas",
    "Rugi kurs",
    "Laba kurs",
    "diag112"
)
Write-Host "`n=== Verification ==="
foreach ($h in $hits) {
    if ($verify.Contains($h)) {
        Write-Host "  FOUND: $h"
    } else {
        Write-Host "  MISSING: $h"
    }
}
