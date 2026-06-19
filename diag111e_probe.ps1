$enc=[System.Text.Encoding]::Unicode
$t=[System.IO.File]::ReadAllText('c:\BTV\debug\w_refresh_journal.srw',$enc)
$out = [System.Text.StringBuilder]::new()

# Show full section around first 'P' voucher setitem (AP section, i=1 block)
$pIdx = $t.IndexOf("voucher_manual+'P'")
$chunk = $t.Substring($pIdx - 30, 800)
$esc = $chunk -replace "`t",'[TAB]' -replace "`r`n",'[CRLF]' -replace "`n",'[LF]' -replace "`r",'[CR]'
[void]$out.AppendLine("=== First AP P block (i=1) ===")
[void]$out.AppendLine($esc)

# Find second P occurrence (new-voucher block)
$pIdx2 = $t.IndexOf("voucher_manual+'P'", $pIdx + 1)
if($pIdx2 -ge 0){
    $chunk2 = $t.Substring($pIdx2 - 100, 800)
    $esc2 = $chunk2 -replace "`t",'[TAB]' -replace "`r`n",'[CRLF]' -replace "`n",'[LF]' -replace "`r",'[CR]'
    [void]$out.AppendLine("`n=== Second AP P block (new voucher) ===")
    [void]$out.AppendLine($esc2)
}

# Show nilai_bayar AP section
$nIdx = $t.IndexOf('//Jika AP, nilai bayar dari debit')
if($nIdx -ge 0){
    $chunk3 = $t.Substring($nIdx, 500)
    $esc3 = $chunk3 -replace "`t",'[TAB]' -replace "`r`n",'[CRLF]' -replace "`n",'[LF]' -replace "`r",'[CR]'
    [void]$out.AppendLine("`n=== nilai_bayar AP section ===")
    [void]$out.AppendLine($esc3)
}

# Show cek apakah full text
$cekIdx = $t.IndexOf('cek apakah ada pembayaran silang')
$chunk4 = $t.Substring([Math]::Max(0,$cekIdx-100), 400)
$esc4 = $chunk4 -replace "`t",'[TAB]' -replace "`r`n",'[CRLF]' -replace "`n",'[LF]' -replace "`r",'[CR]'
[void]$out.AppendLine("`n=== cek apakah section ===")
[void]$out.AppendLine($esc4)

[System.IO.File]::WriteAllText('c:\BTV\debug\diag111e_out.txt', $out.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "Done"
