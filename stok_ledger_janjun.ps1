$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql; $rows=@()
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$o=@{}; for($i=0;$i -lt $rd.FieldCount;$i++){$o[$rd.GetName($i)]=[string]$rd[$i]}; $rows+=$o}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)}
  return $rows }

$accIn = "(select distinct persediaan from im_product_group where persediaan is not null and persediaan<>'')"
$periods = @( @('Jan','2026-02-01'), @('Feb','2026-03-01'), @('Mar','2026-04-01'), @('Apr','2026-05-01'), @('Mei','2026-06-01'), @('Jun','2026-07-01') )

Write-Host "=== A. TOTAL PERSEDIAAN: Ledger vs Stok per bulan ==="
Write-Host ("  {0,-4} {1,22} {2,22} {3,18}" -f 'Bln','Ledger_akhir','Stok_akhir(sinv)','Selisih')
foreach($p in $periods){
  $lbl=$p[0]; $P=$p[1]
  $q=@"
select cast(sum(led) as numeric(18,2)) tled, cast(sum(stk) as numeric(18,2)) tstk, cast(sum(led-stk) as numeric(18,2)) sel from (
 select p.acc, p.opening+isnull(j.ytd,0) led, isnull(s.stok,0) stk
 from (select accountcode acc, sum(amountdebet-amountcredit) opening from gl_balance where site_id='101' and period='2026-01-01' and accountcode in $accIn group by accountcode) p
  left join (select account_id acc, sum(debet-kredit) ytd from gl_journal where posting='P' and tgl>='2026-01-01' and tgl<'$P' and account_id in $accIn group by account_id) j on j.acc=p.acc
  left join (select gr.persediaan acc, sum(sv.nilai) stok from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='$P' group by gr.persediaan) s on s.acc=p.acc
) x
"@
  $r=Reader $q
  if($r.Count -gt 0){ Write-Host ("  {0,-4} {1,22} {2,22} {3,18}" -f $lbl,$r[0].tled,$r[0].tstk,$r[0].sel) }
}

Write-Host "`n=== B. Akun dgn selisih MATERIAL (>1000) per bulan ==="
foreach($p in $periods){
  $lbl=$p[0]; $P=$p[1]
  $q=@"
select p.acc, cast((p.opening+isnull(j.ytd,0))-isnull(s.stok,0) as numeric(18,2)) sel
from (select accountcode acc, sum(amountdebet-amountcredit) opening from gl_balance where site_id='101' and period='2026-01-01' and accountcode in $accIn group by accountcode) p
 left join (select account_id acc, sum(debet-kredit) ytd from gl_journal where posting='P' and tgl>='2026-01-01' and tgl<'$P' and account_id in $accIn group by account_id) j on j.acc=p.acc
 left join (select gr.persediaan acc, sum(sv.nilai) stok from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='$P' group by gr.persediaan) s on s.acc=p.acc
where abs((p.opening+isnull(j.ytd,0))-isnull(s.stok,0)) > 1000
order by abs((p.opening+isnull(j.ytd,0))-isnull(s.stok,0)) desc
"@
  $r=Reader $q
  $line = "  ${lbl}: "
  if($r.Count -eq 0){ $line += "semua nyambung (<=Rp1000)" } else { $line += (($r | ForEach-Object { $_.acc+"="+$_.sel }) -join "  ") }
  Write-Host $line
}
$cn.Close()
