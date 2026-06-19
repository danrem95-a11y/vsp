$ErrorActionPreference = 'Continue'
$outFile = 'C:\BTV\debug\fa_disco4_out.txt'
$output = [System.Collections.Generic.List[string]]::new()

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

function RunQuery($label, $sql) {
    $output.Add(""); $output.Add("===== $label =====")
    try {
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 180
        $rdr = $cmd.ExecuteReader()
        $cols = @(); for ($i=0;$i -lt $rdr.FieldCount;$i++){$cols+=$rdr.GetName($i)}
        $output.Add(($cols -join "`t"))
        $cnt=0
        while ($rdr.Read()) {
            $vals=@(); for($i=0;$i -lt $rdr.FieldCount;$i++){$v=$rdr.GetValue($i);if($v -is [System.DBNull]){$v='(null)'};$vals+=$v}
            $output.Add(($vals -join "`t")); $cnt++
        }
        $rdr.Close(); $output.Add("($cnt rows)")
    } catch { $output.Add("ERROR: $_") }
}

# FAType usage in chart of accounts
RunQuery "gl_acc FAType distribution" @"
SELECT FAType, COUNT(*) AS n FROM gl_acc GROUP BY FAType ORDER BY FAType
"@

# Asset-related accounts by description
RunQuery "gl_acc ASSET/DEPRE accounts by desc" @"
SELECT AccountCode, AccountDes, FinCatCode, AccType, DetailYN, FAType, DebetCredit
FROM gl_acc
WHERE lower(AccountDes) LIKE '%susut%' OR lower(AccountDes) LIKE '%aktiva%'
   OR lower(AccountDes) LIKE '%aset%' OR lower(AccountDes) LIKE '%inventaris%'
   OR lower(AccountDes) LIKE '%kendara%' OR lower(AccountDes) LIKE '%bangun%'
   OR lower(AccountDes) LIKE '%tanah%' OR lower(AccountDes) LIKE '%peralatan%'
   OR lower(AccountDes) LIKE '%mesin%' OR lower(AccountDes) LIKE '%inventory kantor%'
ORDER BY AccountCode
"@

# All header asset accounts 1xx range with FAType set
RunQuery "gl_acc FAType NOT NULL/space accounts" @"
SELECT AccountCode, AccountDes, FinCatCode, FAType, DetailYN
FROM gl_acc WHERE FAType IS NOT NULL AND FAType <> '' AND FAType <> ' '
ORDER BY AccountCode
"@

# gl_cate full (financial categories)
RunQuery "gl_cate ALL" "SELECT FinCatCode, FinCatDes FROM gl_cate ORDER BY FinCatCode"

# Sample PO journal to learn doc_reff/order_reff linking
RunQuery "gl_journal SAMPLE modul=PO (linking fields)" @"
SELECT TOP 8 voucher, urut, tgl, account_id, debet, kredit, modul_id, doc_reff, order_reff, voucher_manual, cust_id, dk, posting
FROM gl_journal WHERE modul_id='PO' AND tgl >= '2026-01-01' ORDER BY voucher, urut
"@

# Sample GJ journal (manual + closing)
RunQuery "gl_journal SAMPLE modul=GJ" @"
SELECT TOP 10 voucher, urut, tgl, account_id, debet, kredit, modul_id, doc_reff, voucher_manual, ket, posting
FROM gl_journal WHERE modul_id='GJ' AND tgl >= '2026-01-01' ORDER BY voucher, urut
"@

# Sample AS journal (unknown module - identify it)
RunQuery "gl_journal SAMPLE modul=AS" @"
SELECT TOP 8 voucher, urut, tgl, account_id, debet, kredit, modul_id, doc_reff, order_reff, ket, posting
FROM gl_journal WHERE modul_id='AS' ORDER BY tgl DESC, voucher, urut
"@

# posting flag distribution
RunQuery "gl_journal POSTING flag distribution" "SELECT posting, COUNT(*) n FROM gl_journal GROUP BY posting"

# dk flag distribution
RunQuery "gl_journal DK flag distribution" "SELECT dk, COUNT(*) n FROM gl_journal GROUP BY dk"

# gl_acc PreFix/DocRNo/DigitNo sample (document numbering)
RunQuery "gl_acc numbering config sample" @"
SELECT TOP 20 AccountCode, AccountDes, PreFix, DocRNo, DigitNo FROM gl_acc
WHERE (PreFix IS NOT NULL AND PreFix<>'') OR (DocRNo IS NOT NULL AND DocRNo<>'')
ORDER BY AccountCode
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
