Add-Type -AssemblyName System.Data

$sql = Get-Content 'c:\BTV\debug\qryopname_ap.sql' -Raw
$sql = $sql.Replace(':arg_tgl1', "'2026-01-01'")
$sql = $sql.Replace(':arg_tgl2', "'2026-01-31'")

$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

$out = @()
try {
    $cmd = $con.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.CommandTimeout = 300
    $r = $cmd.ExecuteReader()
    while ($r.Read()) {
        if ([string]$r['ORDER_CLIENT'] -eq '101BTB251100002') {
            $out += "FOUND|$($r['ORDER_CLIENT'])|$($r['SALDO_AWAL_IDR'])|$($r['MUTASI_IDR'])|$($r['ADJ_IDR'])|$($r['NILAI_BAYAR_IDR'])|$($r['SISA_IDR'])"
        }
    }
    $r.Close()
    if ($out.Count -eq 0) { $out += 'NOT_FOUND' }
}
catch {
    $out += "ERROR=$_"
}
finally {
    $con.Close()
}

$out | Out-File 'c:\BTV\debug\diag31_out.txt' -Encoding UTF8