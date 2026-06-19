Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()
$out = @()
$sqlOp = Get-Content 'c:\BTV\debug\qryopname_ap.sql' -Raw

function RunOp([string]$sql, [string]$tag) {
  $cmd = $con.CreateCommand(); $cmd.CommandTimeout=600
  $cmd.CommandText = $sql
  $r = $cmd.ExecuteReader()
  $rows=0;$sa=[decimal]0;$mut=[decimal]0;$adj=[decimal]0;$byr=[decimal]0;$sisa=[decimal]0
  while ($r.Read()) {
    $rows++
    $sa  += [decimal]$r['SALDO_AWAL_IDR']
    $mut += [decimal]$r['MUTASI_IDR']
    $adj += [decimal]$r['ADJ_IDR']
    $byr += [decimal]$r['NILAI_BAYAR_IDR']
    $sisa+= [decimal]$r['SISA_IDR']
  }
  $r.Close()
  return "$tag|ROWS=$rows|SA=$sa|MUTASI=$mut|ADJ=$adj|BAYAR=$byr|SISA=$sisa"
}

try {
  # Scenario A: no override (0)
  $sqlA = $sqlOp.Replace(':arg_tgl1',"'2026-01-01'").Replace(':arg_tgl2',"'2026-01-31'").Replace(':arg_sa_override','0')
  $out += RunOp $sqlA 'A_NO_OVERRIDE'

  # Scenario B: override = target
  $sqlB = $sqlOp.Replace(':arg_tgl1',"'2026-01-01'").Replace(':arg_tgl2',"'2026-01-31'").Replace(':arg_sa_override','14159923466.61')
  $out += RunOp $sqlB 'B_OVERRIDE_AUDIT'
} finally { $con.Close() }
$out | Out-File 'c:\BTV\debug\diag45_out.txt' -Encoding UTF8
Write-Host ($out -join "`n")
