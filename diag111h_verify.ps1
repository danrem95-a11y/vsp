$enc = [System.Text.Encoding]::Unicode
$t = [System.IO.File]::ReadAllText('c:\BTV\debug\w_refresh_journal.srw', $enc)

# Find all occurrences of ll_bank_kas, ls_bank_curr, ldec_bank_kurs in setitem lines
$lines = $t -split "`r`n"
$n = 0
foreach($line in $lines){
    $n++
    if($line -match "setitem.*ll_bank_kas|setitem.*ls_bank_curr|setitem.*ldec_bank_kurs"){
        Write-Host "Line $n: $($line.Trim())"
    }
}
Write-Host "Total lines: $n"
