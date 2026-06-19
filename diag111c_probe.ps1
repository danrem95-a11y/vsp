$enc=[System.Text.Encoding]::Unicode
$t=[System.IO.File]::ReadAllText('c:\BTV\debug\w_refresh_journal.srw',$enc)
$i=$t.IndexOf('cek apakah ada pembayaran silang')
"Found 'cek apakah' at char: $i"
if($i -ge 0){
    $chunk = $t.Substring([Math]::Max(0,$i-200), 300)
    # Show as escaped string
    $escaped = $chunk -replace "`t",'[TAB]' -replace "`r`n",'[CRLF]' -replace "`n",'[LF]' -replace "`r",'[CR]'
    "Escaped view:"
    $escaped
}

# Check the 'P' setitem block
$i2 = $t.IndexOf("'P')")
if($i2 -ge 0){
    $chunk2 = $t.Substring($i2, 200)
    $escaped2 = $chunk2 -replace "`t",'[TAB]' -replace "`r`n",'[CRLF]' -replace "`n",'[LF]' -replace "`r",'[CR]'
    "`nFirst 'P') at char $i2"
    $escaped2
}

# Find the AP 'P' setitem specifically
$i3 = $t.IndexOf(",'P')" + [char]13 + [char]10)
$i4 = $t.IndexOf(",'P')" + [char]10)
"CRLF after 'P' at: $i3"
"LF after 'P' at: $i4"
