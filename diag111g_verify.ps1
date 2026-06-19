$enc = [System.Text.Encoding]::Unicode
$t = [System.IO.File]::ReadAllText('c:\BTV\debug\w_refresh_journal.srw', $enc)
$out = [System.Text.StringBuilder]::new()

# Show the bank lookup section
$i = $t.IndexOf('Ambil curr_id, kurs, kas_id dari baris kas')
if($i -ge 0){
    [void]$out.AppendLine("=== Bank row lookup inserted (R2) ===")
    [void]$out.AppendLine($t.Substring($i, 600))
}

# Show first tbyr1 block after R3
$i2 = $t.IndexOf("ll_bank_kas)")
if($i2 -ge 0){
    [void]$out.AppendLine("`n=== R3 fix (ll_bank_kas) context ===")
    [void]$out.AppendLine($t.Substring([Math]::Max(0,$i2-100), 300))
}

# Show nilai_bayar fix
$i3 = $t.IndexOf('ldec_bayar_kurs > 0 and ldec_bayar_kurs < ldec_bayar')
if($i3 -ge 0){
    [void]$out.AppendLine("`n=== R5 fix (nilai_bayar) context ===")
    [void]$out.AppendLine($t.Substring([Math]::Max(0,$i3-200), 500))
}

[System.IO.File]::WriteAllText('c:\BTV\debug\diag111_verify.txt', $out.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "Done"
