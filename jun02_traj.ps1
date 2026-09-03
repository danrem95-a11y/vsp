$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== Grup utk 102-001 & 102-201 ==="
Reader "select persediaan, kode_group, nama_group, hpp from im_product_group where persediaan in ('102-001','102-201') order by persediaan"

Write-Host "`n=== STOK per periode (sinv) 102-001 & 102-201 ==="
Reader @"
select gr.persediaan acc, sv.periode, cast(sum(sv.nilai) as numeric(18,2)) stok
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan in ('102-001','102-201') and sv.periode between '2026-01-01' and '2026-07-01'
group by gr.persediaan, sv.periode order by gr.persediaan, sv.periode
"@

Write-Host "`n=== GL opening 2026 (102-001 & 102-201) ==="
Reader "select accountcode acc, cast(sum(amountdebet-amountcredit) as numeric(18,2)) opening from gl_balance where site_id='101' and period='2026-01-01' and accountcode in ('102-001','102-201') group by accountcode"

Write-Host "`n=== GL mutasi per BULAN (102-001 & 102-201) ==="
Reader @"
select account_id acc, month(tgl) m, cast(sum(debet-kredit) as numeric(18,2)) net, count(*) n
from gl_journal where posting='P' and tgl>='2026-01-01' and tgl<'2026-07-01' and account_id in ('102-001','102-201')
group by account_id, month(tgl) order by account_id, month(tgl)
"@

$cn.Close()
