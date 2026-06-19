# Fix w_refresh_journal.srw - AP Refresh (cb_7) R2-R5 with correct TAB indentation
# R1 (variable declarations) was already applied in the previous run.
# File uses TAB indentation and CRLF line endings within UTF-16LE encoding.

$srcFile = "c:\BTV\debug\w_refresh_journal.srw"
$enc = [System.Text.Encoding]::Unicode

$content = [System.IO.File]::ReadAllText($srcFile, $enc)
$NL = "`r`n"
$T  = "`t"      # tab
$TT = "`t`t"    # 2 tabs
$TTT= "`t`t`t"  # 3 tabs

# Helper to confirm a pattern exists before replacement
function TryReplace($label, [ref]$str, $old, $new) {
    if ($str.Value.Contains($old)) {
        $str.Value = $str.Value.Replace($old, $new)
        Write-Host "$label OK"
    } else {
        Write-Host "$label MISS"
    }
}

# -----------------------------------------------------------------------
# R2: Insert bank-row lookup before AP/AR routing
#     Pattern unique to AP section: ends with  "//AP" (not "//AR" in cb_5)
# -----------------------------------------------------------------------
$old2 = "${T}if isnull(ls_faktur_silang) then ls_faktur_silang = ''${NL}${NL}${T}//cek apakah ada pembayaran silang, antara AP diadu ke AR${NL}${T}${NL}${T}if ls_faktur = '' and ls_faktur_silang = '' then continue; //Mungkin ini biaya adm, selisih kurs${NL}${T}if ls_faktur <> '' then //AP"

$bankLookup = `
"${T}//Ambil curr_id, kurs, kas_id dari baris kas/bank (row yg punya kas_id>0, mis. BCA)${NL}${T}//(baris bank punya doc_reff/order_reff kosong sehingga tidak masuk d_gl_bayar_ap)${NL}${T}ls_bank_curr = 'IDR'${NL}${T}ldec_bank_kurs = 1${NL}${T}ll_bank_kas = 0${NL}${T}select top 1 curr_id, rate_rp, kas_id${NL}${T}into :ls_bank_curr, :ldec_bank_kurs, :ll_bank_kas${NL}${T}from gl_journal${NL}${T}where voucher_manual = :ls_voucher_manual${NL}${T}  and kas_id > 0${NL}${T}using sqlca;${NL}${T}if isnull(ls_bank_curr) or ls_bank_curr = '' then ls_bank_curr = 'IDR'${NL}${T}if isnull(ldec_bank_kurs) or ldec_bank_kurs = 0 then ldec_bank_kurs = 1${NL}${T}if isnull(ll_bank_kas) then ll_bank_kas = 0"

$new2 = "${T}if isnull(ls_faktur_silang) then ls_faktur_silang = ''${NL}${NL}${bankLookup}${NL}${NL}${T}//cek apakah ada pembayaran silang, antara AP diadu ke AR${NL}${T}${NL}${T}if ls_faktur = '' and ls_faktur_silang = '' then continue; //Mungkin ini biaya adm, selisih kurs${NL}${T}if ls_faktur <> '' then //AP"

TryReplace "R2" ([ref]$content) $old2 $new2

# -----------------------------------------------------------------------
# R3: Fix tbyr1 first block (i=1) - 2-tab indent, flag_bayar=ll_flag_bayar
# -----------------------------------------------------------------------
$old3 = "ls_voucher_manual+'P')${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'flag_bayar',ll_flag_bayar)${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'tgl',ldt_tgl)${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'site_id',gs_site)${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'kas_id',ll_kas)${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'kolektor_id','')${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'voucher_manual',ls_voucher_manual)${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'curr_id',ls_curr)${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'kurs',ldec_kurs)"

$new3 = "ls_voucher_manual+'P')${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'flag_bayar',ll_flag_bayar)${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'tgl',ldt_tgl)${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'site_id',gs_site)${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'kas_id',ll_bank_kas)${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'kolektor_id','')${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'voucher_manual',ls_voucher_manual)${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'curr_id',ls_bank_curr)${NL}${TT}dw_sync1.setitem(dw_sync1.getrow(),'kurs',ldec_bank_kurs)"

TryReplace "R3" ([ref]$content) $old3 $new3

# -----------------------------------------------------------------------
# R4: Fix tbyr1 new-voucher block - 3-tab indent, flag_bayar=2 (hardcoded)
# -----------------------------------------------------------------------
$old4 = "ls_voucher_manual+'P')${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'flag_bayar',2)${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'tgl',ldt_tgl)${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'site_id',gs_site)${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'kas_id',ll_kas)${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'kolektor_id','')${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'voucher_manual',ls_voucher_manual)${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'curr_id',ls_curr)${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'kurs',ldec_kurs)"

$new4 = "ls_voucher_manual+'P')${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'flag_bayar',2)${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'tgl',ldt_tgl)${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'site_id',gs_site)${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'kas_id',ll_bank_kas)${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'kolektor_id','')${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'voucher_manual',ls_voucher_manual)${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'curr_id',ls_bank_curr)${NL}${TTT}dw_sync1.setitem(dw_sync1.getrow(),'kurs',ldec_bank_kurs)"

TryReplace "R4" ([ref]$content) $old4 $new4

# -----------------------------------------------------------------------
# R5: Fix tbyr2.nilai_bayar - AP section only (//Jika AP comment is unique here)
#     [TAB][CRLF] = tab-only blank line between 'end if' blocks
# -----------------------------------------------------------------------
$old5 = "//Jika AP, nilai bayar dari debit, jika AR nilai bayar dari kredit${NL}${T}if ll_flag_bayar = 2 then${NL}${TT}ldec_bayar = ldec_debet${NL}${TT}ldec_bayar_kurs = ldec_debet_kurs${NL}${T}else${NL}${TT}ldec_bayar = ldec_kredit${NL}${TT}ldec_bayar_kurs = ldec_kredit_kurs${NL}${T}end if${NL}${T}${NL}${T}if ls_curr_jual = 'IDR' then${NL}${TT}ldec_set_bayar = ldec_bayar${NL}${T}else${NL}${TT}ldec_set_bayar = ldec_bayar_kurs${NL}${T}end if"

$new5 = "//Jika AP, nilai bayar dari debit, jika AR nilai bayar dari kredit${NL}${T}if ll_flag_bayar = 2 then${NL}${TT}ldec_bayar = ldec_debet${NL}${TT}ldec_bayar_kurs = ldec_debet_kurs${NL}${T}else${NL}${TT}ldec_bayar = ldec_kredit${NL}${TT}ldec_bayar_kurs = ldec_kredit_kurs${NL}${T}end if${NL}${T}${NL}${T}if ls_curr_jual = 'IDR' then${NL}${TT}ldec_set_bayar = ldec_bayar${NL}${T}else${NL}${TT}//Nilai bayar harus dalam valuta asing (mis. USD untuk invoice USD)${NL}${TT}//Jika debet_kurs < debet maka debet_kurs sudah berisi nilai foreign (mis. 26720 USD)${NL}${TT}//Jika debet_kurs = debet (IDR) atau 0, hitung dari IDR / kurs sebagai fallback${NL}${TT}if ldec_bayar_kurs > 0 and ldec_bayar_kurs < ldec_bayar then${NL}${TTT}ldec_set_bayar = ldec_bayar_kurs${NL}${TT}elseif ldec_kurs > 1 then${NL}${TTT}ldec_set_bayar = ldec_bayar / ldec_kurs${NL}${TT}else${NL}${TTT}ldec_set_bayar = ldec_bayar${NL}${TT}end if${NL}${T}end if"

TryReplace "R5" ([ref]$content) $old5 $new5

# -----------------------------------------------------------------------
# Write result
# -----------------------------------------------------------------------
[System.IO.File]::WriteAllText($srcFile, $content, $enc)
Write-Host "`nFile written: $srcFile"

# Verify
$verify = [System.IO.File]::ReadAllText($srcFile, $enc)
$hits = @(
    "ls_bank_curr",
    "ldec_bank_kurs",
    "ll_bank_kas",
    "select top 1 curr_id, rate_rp, kas_id",
    "kas_id > 0",
    "ldec_bayar_kurs > 0 and ldec_bayar_kurs < ldec_bayar",
    "ldec_bayar / ldec_kurs",
    "ldec_bank_kas"
)
Write-Host "`n=== Verification ==="
foreach ($h in $hits) {
    if ($verify.Contains($h)) { Write-Host "  FOUND: $h" }
    else { Write-Host "  MISSING: $h" }
}
