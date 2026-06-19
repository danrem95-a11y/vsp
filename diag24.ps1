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

    $rows = 0
    $sa = [decimal]0
    $mut = [decimal]0
    $adj = [decimal]0
    $byr = [decimal]0
    $sisa = [decimal]0

    while ($r.Read()) {
        $rows++
        $sa += [decimal]$r['SALDO_AWAL_IDR']
        $mut += [decimal]$r['MUTASI_IDR']
        $adj += [decimal]$r['ADJ_IDR']
        $byr += [decimal]$r['NILAI_BAYAR_IDR']
        $sisa += [decimal]$r['SISA_IDR']
    }
    $r.Close()

    $out += "ROWS=$rows"
    $out += "SA=$sa"
    $out += "MUTASI=$mut"
    $out += "ADJ=$adj"
    $out += "BAYAR=$byr"
    $out += "SISA=$sisa"
}
catch {
    $out += "ERROR=$_"
}
finally {
    $con.Close()
}

$out | Out-File 'c:\BTV\debug\diag24_out.txt' -Encoding UTF8