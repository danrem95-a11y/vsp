$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Val($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql; try{$v=$c.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return [decimal]0}; return [decimal]$v}catch{return "ERR:"+$_.Exception.Message } }
$ap=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ap_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
$ap_open = Val "select isnull(sum(amountcredit-amountdebet),0) from gl_balance where site_id='101' and period='2026-01-01' and accountcode in ('226-001','226-006')"

Write-Host "=== SIMULASI OPSI A (DP 2026 yg di-apply opname saja) ==="
Write-Host ("  {0,-4} {1,20} {2,20} {3,18} {4,20} {5,14}" -f 'Bln','Opname','Ledger_skrg','DP_2026_kumul','Ledger_stlh_A','Gap_stlh_A')
foreach($p in @(@('Feb','2026-02-01','2026-02-28','2026-03-01'),@('Apr','2026-04-01','2026-04-30','2026-05-01'),@('Mei','2026-05-01','2026-05-31','2026-06-01'),@('Jun','2026-06-01','2026-06-30','2026-07-01'))){
  $lbl=$p[0]; $t1=$p[1]; $t2=$p[2]; $P=$p[3]
  $led = $ap_open + (Val "select isnull(sum(kredit-debet),0) from gl_journal where posting='P' and account_id in ('226-001','226-006') and tgl>='2026-01-01' and tgl<'$P'")
  $dp  = Val "select isnull(sum(t2.nilai_bayar_idr),0) from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t1.flag_bayar in (1,2) and upper(t1.voucher_manual) like '%DPB%' and t1.tgl>='2026-01-01' and t1.tgl<'$P'"
  $q=$ap -replace ':arg_tgl1',"'$t1'" -replace ':arg_tgl2',"'$t2'"
  $opn = Val "select isnull(sum(SISA_IDR),0) from ($q) x"
  $led_after = $led - $dp
  Write-Host ("  {0,-4} {1,20:N2} {2,20:N2} {3,18:N2} {4,20:N2} {5,14:N2}" -f $lbl,$opn,$led,$dp,$led_after,($opn-$led_after))
}
$cn.Close()
