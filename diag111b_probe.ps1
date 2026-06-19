$enc=[System.Text.Encoding]::Unicode
$t=[System.IO.File]::ReadAllText('c:\BTV\debug\w_refresh_journal.srw',$enc)
$i=$t.IndexOf('cek apakah ada pembayaran silang')
"Found 'cek apakah' at char: $i"
if($i -ge 0){
    $chunk = $t.Substring([Math]::Max(0,$i-300), 500)
    [System.IO.File]::WriteAllText('c:\BTV\debug\diag111_probe.txt', $chunk, [System.Text.Encoding]::UTF8)
    "Written to diag111_probe.txt"
}

$i2=$t.IndexOf("'P')`r`n                dw_sync1.setitem(dw_sync1.getrow(),'flag_bayar'")
"Found P+flag_bayar at: $i2"

$i3=$t.IndexOf("'P')`r`n                dw_sync1.setitem")
"Found P+setitem at: $i3"
