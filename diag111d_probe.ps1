$enc=[System.Text.Encoding]::Unicode
$t=[System.IO.File]::ReadAllText('c:\BTV\debug\w_refresh_journal.srw',$enc)
$i=$t.IndexOf('cek apakah ada pembayaran silang')

# Write probe to UTF-8 output file
$out = [System.Text.StringBuilder]::new()
[void]$out.AppendLine("Found 'cek apakah' at char: $i")
if($i -ge 0){
    $chunk = $t.Substring([Math]::Max(0,$i-200), 300)
    $escaped = $chunk -replace "`t",'[TAB]' -replace "`r`n",'[CRLF]' -replace "`n",'[LF]' -replace "`r",'[CR]'
    [void]$out.AppendLine("Escaped view:")
    [void]$out.AppendLine($escaped)
}

# Find AP 'P' pattern
$patterns = @(
    "dw_sync1.getrow(),'voucher_manual'+'P'",
    "ls_voucher_manual+`"P`"",
    "ls_voucher_manual+'P'",
    'ls_voucher_manual+' + "'P'"
)
foreach($p in $patterns){
    $idx = $t.IndexOf($p)
    [void]$out.AppendLine("Pattern '$p': $idx")
}

# Show 200 chars around first 'P' setitem occurrence 
$pIdx = $t.IndexOf("voucher_manual+'P'")
if($pIdx -ge 0){
    $chunk3 = $t.Substring($pIdx, 400)
    $esc3 = $chunk3 -replace "`t",'[TAB]' -replace "`r`n",'[CRLF]' -replace "`n",'[LF]' -replace "`r",'[CR]'
    [void]$out.AppendLine("`nvoucher_manual+'P' at $pIdx")
    [void]$out.AppendLine($esc3)
}

[System.IO.File]::WriteAllText('c:\BTV\debug\diag111d_out.txt', $out.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "Done"
