$ErrorActionPreference = 'Stop'
$sql = Get-Content c:\BTV\debug\qryopname_ap.sql -Raw
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

function Fetch($t1, $t2) {
  $s = $sql -replace ':arg_tgl1', "'$t1'" -replace ':arg_tgl2', "'$t2'"
  $s = $s.TrimEnd().TrimEnd(';')
  $q = "SELECT ORDER_CLIENT, SALDO_AWAL_IDR, MUTASI_IDR, ADJ_IDR, NILAI_BAYAR_IDR, SISA_IDR FROM ($s) X"
  $c = $conn.CreateCommand(); $c.CommandText = $q; $c.CommandTimeout = 600
  $r = $c.ExecuteReader()
  $h = @{}
  while ($r.Read()) {
    $h[$r['ORDER_CLIENT']] = [pscustomobject]@{
      SA   = [decimal]$r['SALDO_AWAL_IDR']
      MU   = [decimal]$r['MUTASI_IDR']
      ADJ  = [decimal]$r['ADJ_IDR']
      BYR  = [decimal]$r['NILAI_BAYAR_IDR']
      SISA = [decimal]$r['SISA_IDR']
    }
  }
  $r.Close()
  $h
}

$jan = Fetch '2026-01-01' '2026-01-31'
$feb = Fetch '2026-02-01' '2026-02-28'
$conn.Close()

"Jan rows: $($jan.Count)  Feb rows: $($feb.Count)"

$keys = ($jan.Keys + $feb.Keys) | Sort-Object -Unique
$diffs = @()
foreach ($k in $keys) {
  $sj = if ($jan.ContainsKey($k)) { $jan[$k].SISA } else { 0 }
  $sf = if ($feb.ContainsKey($k)) { $feb[$k].SA } else { 0 }
  $d = $sf - $sj
  if ([math]::Abs($d) -gt 0.5) {
    $inJ = $jan.ContainsKey($k); $inF = $feb.ContainsKey($k)
    $diffs += [pscustomobject]@{ VC=$k; SISA_JAN=$sj; SA_FEB=$sf; DIFF=$d; InJan=$inJ; InFeb=$inF }
  }
}
"Mismatched vouchers: $($diffs.Count)"
"Total DIFF: $(($diffs | Measure-Object DIFF -Sum).Sum)"
$diffs | Sort-Object @{Expression={[math]::Abs($_.DIFF)}; Descending=$true} | Select-Object -First 30 | Format-Table -AutoSize
$diffs | Sort-Object @{Expression={[math]::Abs($_.DIFF)}; Descending=$true} | ConvertTo-Csv -NoTypeInformation | Out-File c:\BTV\debug\diag51_out.csv -Encoding ascii
