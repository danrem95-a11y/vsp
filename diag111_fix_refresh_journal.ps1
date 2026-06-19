# Fix w_refresh_journal.srw - AP Refresh (cb_7) currency and valuta bugs
# Root cause:
#  1. tbyr1.curr_id/kurs/kas_id are taken from the AP journal row (e.g. 226-001 Hutang Dagang, USD)
#     instead of the bank/kas row (e.g. 101-011 BCA, IDR). This makes tbyr1.curr_id = 'USD'
#     and kurs = 16782 after refresh, when it should be 'IDR'/1.
#  2. tbyr2.nilai_bayar (Valuta) gets Rp amount instead of $ amount for USD invoices because
#     debet_kurs in gl_journal may store IDR; the fix computes foreign amount = debet/kurs as fallback.

$srcFile = "c:\BTV\debug\w_refresh_journal.srw"
$bakFile = "c:\BTV\debug\w_refresh_journal.srw.bak_diag111"

# Backup
Copy-Item $srcFile $bakFile -Force
Write-Host "Backup: $bakFile"

$enc = [System.Text.Encoding]::Unicode
$content = [System.IO.File]::ReadAllText($srcFile, $enc)

# -----------------------------------------------------------------------
# R1: Add new variable declarations after "long ll_gl_count, i_gl, ll_all"
# Only in cb_7 AP section (which has dw_update.dataobject = 'd_gl_bayar_ap' nearby)
# -----------------------------------------------------------------------
$old1 = "string ls_order`r`nlong ll_gl_count, i_gl, ll_all"
$new1 = "string ls_order`r`nlong ll_gl_count, i_gl, ll_all`r`nstring ls_bank_curr`r`ndecimal ldec_bank_kurs`r`nlong ll_bank_kas"

if ($content.Contains($old1)) {
    $content = $content.Replace($old1, $new1)
    Write-Host "R1 OK: Added ls_bank_curr / ldec_bank_kurs / ll_bank_kas declarations"
} else {
    Write-Host "R1 MISS: Declaration pattern not found"
}

# -----------------------------------------------------------------------
# R2: Insert bank-row lookup before the AP/AR routing block.
#     Target: the null-checks + comment just before AP/AR condition.
# -----------------------------------------------------------------------
$old2 = "        if isnull(ls_faktur) then ls_faktur = ''`r`n        if isnull(ls_faktur_silang) then ls_faktur_silang = ''`r`n`r`n        //cek apakah ada pembayaran silang, antara AP diadu ke AR"
$new2 = "        if isnull(ls_faktur) then ls_faktur = ''`r`n        if isnull(ls_faktur_silang) then ls_faktur_silang = ''`r`n`r`n        //Ambil curr_id, kurs, kas_id dari baris kas/bank (urut 1) yg TIDAK masuk query d_gl_bayar_ap`r`n        //karena doc_reff/order_reff-nya kosong, sehingga tbyr1 harus pakai data bank bukan data AP`r`n        ls_bank_curr = 'IDR'`r`n        ldec_bank_kurs = 1`r`n        ll_bank_kas = 0`r`n        select top 1 curr_id, rate_rp, kas_id`r`n        into :ls_bank_curr, :ldec_bank_kurs, :ll_bank_kas`r`n        from gl_journal`r`n        where voucher_manual = :ls_voucher_manual`r`n          and kas_id > 0`r`n        using sqlca;`r`n        if isnull(ls_bank_curr) or ls_bank_curr = '' then ls_bank_curr = 'IDR'`r`n        if isnull(ldec_bank_kurs) or ldec_bank_kurs = 0 then ldec_bank_kurs = 1`r`n        if isnull(ll_bank_kas) then ll_bank_kas = 0`r`n`r`n        //cek apakah ada pembayaran silang, antara AP diadu ke AR"

if ($content.Contains($old2)) {
    $content = $content.Replace($old2, $new2)
    Write-Host "R2 OK: Inserted bank-row lookup"
} else {
    Write-Host "R2 MISS: Null-check + cek-silang pattern not found - trying alternate"
    # Try without the blank line between null checks and comment
    $old2b = "        if isnull(ls_faktur) then ls_faktur = ''`r`n        if isnull(ls_faktur_silang) then ls_faktur_silang = ''`r`n        //cek apakah ada pembayaran silang, antara AP diadu ke AR"
    $new2b = "        if isnull(ls_faktur) then ls_faktur = ''`r`n        if isnull(ls_faktur_silang) then ls_faktur_silang = ''`r`n`r`n        //Ambil curr_id, kurs, kas_id dari baris kas/bank (urut 1) yg TIDAK masuk query d_gl_bayar_ap`r`n        //karena doc_reff/order_reff-nya kosong, sehingga tbyr1 harus pakai data bank bukan data AP`r`n        ls_bank_curr = 'IDR'`r`n        ldec_bank_kurs = 1`r`n        ll_bank_kas = 0`r`n        select top 1 curr_id, rate_rp, kas_id`r`n        into :ls_bank_curr, :ldec_bank_kurs, :ll_bank_kas`r`n        from gl_journal`r`n        where voucher_manual = :ls_voucher_manual`r`n          and kas_id > 0`r`n        using sqlca;`r`n        if isnull(ls_bank_curr) or ls_bank_curr = '' then ls_bank_curr = 'IDR'`r`n        if isnull(ldec_bank_kurs) or ldec_bank_kurs = 0 then ldec_bank_kurs = 1`r`n        if isnull(ll_bank_kas) then ll_bank_kas = 0`r`n`r`n        //cek apakah ada pembayaran silang, antara AP diadu ke AR"
    if ($content.Contains($old2b)) {
        $content = $content.Replace($old2b, $new2b)
        Write-Host "R2b OK: Inserted bank-row lookup (alt)"
    } else {
        Write-Host "R2b MISS: Still not found"
    }
}

# -----------------------------------------------------------------------
# R3: Fix tbyr1 first block (i = 1) - kas_id, curr_id, kurs
#     Context: 'voucher_manual+''P''' (AP suffix) and 'flag_bayar',ll_flag_bayar
# -----------------------------------------------------------------------
$old3 = "                dw_sync1.setitem(dw_sync1.getrow(),'voucher',ls_voucher_manual+'P')`r`n                dw_sync1.setitem(dw_sync1.getrow(),'flag_bayar',ll_flag_bayar)`r`n                dw_sync1.setitem(dw_sync1.getrow(),'tgl',ldt_tgl)`r`n                dw_sync1.setitem(dw_sync1.getrow(),'site_id',gs_site)`r`n                dw_sync1.setitem(dw_sync1.getrow(),'kas_id',ll_kas)`r`n                dw_sync1.setitem(dw_sync1.getrow(),'kolektor_id','')`r`n                dw_sync1.setitem(dw_sync1.getrow(),'voucher_manual',ls_voucher_manual)`r`n                dw_sync1.setitem(dw_sync1.getrow(),'curr_id',ls_curr)`r`n                dw_sync1.setitem(dw_sync1.getrow(),'kurs',ldec_kurs)"
$new3 = "                dw_sync1.setitem(dw_sync1.getrow(),'voucher',ls_voucher_manual+'P')`r`n                dw_sync1.setitem(dw_sync1.getrow(),'flag_bayar',ll_flag_bayar)`r`n                dw_sync1.setitem(dw_sync1.getrow(),'tgl',ldt_tgl)`r`n                dw_sync1.setitem(dw_sync1.getrow(),'site_id',gs_site)`r`n                dw_sync1.setitem(dw_sync1.getrow(),'kas_id',ll_bank_kas)`r`n                dw_sync1.setitem(dw_sync1.getrow(),'kolektor_id','')`r`n                dw_sync1.setitem(dw_sync1.getrow(),'voucher_manual',ls_voucher_manual)`r`n                dw_sync1.setitem(dw_sync1.getrow(),'curr_id',ls_bank_curr)`r`n                dw_sync1.setitem(dw_sync1.getrow(),'kurs',ldec_bank_kurs)"

if ($content.Contains($old3)) {
    $content = $content.Replace($old3, $new3)
    Write-Host "R3 OK: Fixed kas_id/curr_id/kurs in tbyr1 first block (i=1)"
} else {
    Write-Host "R3 MISS: First tbyr1 block pattern not found"
}

# -----------------------------------------------------------------------
# R4: Fix tbyr1 new-voucher block - kas_id, curr_id, kurs (24-space indent)
# -----------------------------------------------------------------------
$old4 = "                        dw_sync1.setitem(dw_sync1.getrow(),'voucher',ls_voucher_manual+'P')`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'flag_bayar',2)`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'tgl',ldt_tgl)`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'site_id',gs_site)`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'kas_id',ll_kas)`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'kolektor_id','')`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'voucher_manual',ls_voucher_manual)`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'curr_id',ls_curr)`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'kurs',ldec_kurs)"
$new4 = "                        dw_sync1.setitem(dw_sync1.getrow(),'voucher',ls_voucher_manual+'P')`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'flag_bayar',2)`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'tgl',ldt_tgl)`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'site_id',gs_site)`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'kas_id',ll_bank_kas)`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'kolektor_id','')`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'voucher_manual',ls_voucher_manual)`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'curr_id',ls_bank_curr)`r`n                        dw_sync1.setitem(dw_sync1.getrow(),'kurs',ldec_bank_kurs)"

if ($content.Contains($old4)) {
    $content = $content.Replace($old4, $new4)
    Write-Host "R4 OK: Fixed kas_id/curr_id/kurs in tbyr1 new-voucher block"
} else {
    Write-Host "R4 MISS: New-voucher tbyr1 block pattern not found"
}

# -----------------------------------------------------------------------
# R5: Fix tbyr2.nilai_bayar - in AP section only (after "//Jika AP..." comment)
#     Replace simple ldec_bayar_kurs fallback with safe foreign-amount logic
# -----------------------------------------------------------------------
$old5 = "        //Jika AP, nilai bayar dari debit, jika AR nilai bayar dari kredit`r`n        if ll_flag_bayar = 2 then`r`n                ldec_bayar = ldec_debet`r`n                ldec_bayar_kurs = ldec_debet_kurs`r`n        else`r`n                ldec_bayar = ldec_kredit`r`n                ldec_bayar_kurs = ldec_kredit_kurs`r`n        end if`r`n`r`n        if ls_curr_jual = 'IDR' then`r`n                ldec_set_bayar = ldec_bayar`r`n        else`r`n                ldec_set_bayar = ldec_bayar_kurs`r`n        end if"
$new5 = "        //Jika AP, nilai bayar dari debit, jika AR nilai bayar dari kredit`r`n        if ll_flag_bayar = 2 then`r`n                ldec_bayar = ldec_debet`r`n                ldec_bayar_kurs = ldec_debet_kurs`r`n        else`r`n                ldec_bayar = ldec_kredit`r`n                ldec_bayar_kurs = ldec_kredit_kurs`r`n        end if`r`n`r`n        if ls_curr_jual = 'IDR' then`r`n                ldec_set_bayar = ldec_bayar`r`n        else`r`n                //Nilai bayar dalam valuta asing (misalnya USD)`r`n                //Jika debet_kurs < debet berarti sudah berisi nilai foreign currency (mis. USD)`r`n                //Jika debet_kurs = debet (atau 0), hitung dari IDR dibagi kurs`r`n                if ldec_bayar_kurs > 0 and ldec_bayar_kurs < ldec_bayar then`r`n                        ldec_set_bayar = ldec_bayar_kurs`r`n                elseif ldec_kurs > 1 then`r`n                        ldec_set_bayar = ldec_bayar / ldec_kurs`r`n                else`r`n                        ldec_set_bayar = ldec_bayar`r`n                end if`r`n        end if"

if ($content.Contains($old5)) {
    $content = $content.Replace($old5, $new5)
    Write-Host "R5 OK: Fixed tbyr2.nilai_bayar (Valuta) for foreign currency invoices"
} else {
    Write-Host "R5 MISS: nilai_bayar pattern not found (AP section)"
}

# -----------------------------------------------------------------------
# Write result
# -----------------------------------------------------------------------
[System.IO.File]::WriteAllText($srcFile, $content, $enc)
Write-Host "`nDone. File written: $srcFile"

# Verify by searching for new tokens
$verify = [System.IO.File]::ReadAllText($srcFile, $enc)
$hits = @(
    "ls_bank_curr",
    "ldec_bank_kurs",
    "ll_bank_kas",
    "select top 1 curr_id, rate_rp, kas_id",
    "ldec_bank_kurs > 0 and ldec_bayar_kurs < ldec_bayar",
    "ldec_bayar / ldec_kurs"
)
Write-Host "`n=== Verification ==="
foreach ($h in $hits) {
    if ($verify.Contains($h)) {
        Write-Host "  FOUND: $h"
    } else {
        Write-Host "  MISSING: $h"
    }
}
