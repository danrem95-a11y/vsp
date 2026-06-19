$enc = [System.Text.Encoding]::Unicode
$t = [System.IO.File]::ReadAllText('c:\BTV\debug\w_refresh_journal.srw', $enc)
$lines = $t -split "`r`n"
$found = @()
$n = 0
foreach($line in $lines){
    $n++
    if($line -match 'setitem.*ll_bank_kas|setitem.*ls_bank_curr|setitem.*ldec_bank_kurs'){
        $found += ('Line ' + $n + ': ' + $line.TrimStart())
    }
}
$result = "Total lines: $n, setitem bank matches: " + $found.Count
$result
$found | ForEach-Object { $_ }
