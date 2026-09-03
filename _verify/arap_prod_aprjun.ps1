$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Val($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=800; $c.CommandText=$sql; try{$v=$c.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return 0}; return [decimal]$v}catch{return "ERR" } }
function N($d){ if($d -is [string]){return $d}; return ('{0:N2}' -f $d) }
$ar=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ar_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
$ap=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ap_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
function OPN($tpl,$t1,$t2){ $q=$tpl -replace ':arg_tgl1',"'$t1'" -replace ':arg_tgl2',"'$t2'"; return Val "select sum(SISA_IDR) from ($q) x" }
$periods = @( @('Apr','2026-04-01','2026-04-30','2026-05-01'), @('Mei','2026-05-01','2026-05-31','2026-06-01'), @('Jun','2026-06-01','2026-06-30','2026-07-01') )
$ar_open = Val "select isnull(sum(amountdebet-amountcredit),0) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='103-001'"
$ap_open = Val "select isnull(sum(amountcredit-amountdebet),0) from gl_balance where site_id='101' and period='2026-01-01' and accountcode in ('226-001','226-006')"
Write-Host ("{0,-4} | {1,-28} | {2,-28}" -f 'Bln','AR opname-vs-Ledger(103-001)','AP opname-vs-Ledger(226)')
Write-Host ("-"*70)
foreach($p in $periods){
  $lbl=$p[0]; $t1=$p[1]; $t2=$p[2]; $P=$p[3]
  $ar_led = $ar_open + (Val "select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and account_id='103-001' and tgl>='2026-01-01' and tgl<'$P'")
  $ar_opn = OPN $ar $t1 $t2
  $ap_led = $ap_open + (Val "select isnull(sum(kredit-debet),0) from gl_journal where posting='P' and account_id in ('226-001','226-006') and tgl>='2026-01-01' and tgl<'$P'")
  $ap_opn = OPN $ap $t1 $t2
  $arg = if($ar_opn -is [string]){'ERR'}else{N ($ar_opn-$ar_led)}
  $apg = if($ap_opn -is [string]){'ERR'}else{N ($ap_opn-$ap_led)}
  Write-Host ("{0,-4} | ar_opname={1,18} | ar_ledger={2,18} | gap={3,18}" -f $lbl,(N $ar_opn),(N $ar_led),$arg)
  Write-Host ("     | ap_opname={0,18} | ap_ledger={1,18} | gap={2,18}" -f (N $ap_opn),(N $ap_led),$apg)
}
$cn.Close()
