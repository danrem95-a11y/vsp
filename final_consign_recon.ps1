$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Rows($sql){ $c=$P.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql; $o=@(); $rd=$c.ExecuteReader(); while($rd.Read()){ $r=@{}; for($i=0;$i -lt $rd.FieldCount;$i++){$r[$rd.GetName($i)]=$rd[$i]}; $o+=$r }; $rd.Close(); return $o }
$accIn="(select distinct persediaan from im_product_group where persediaan is not null and persediaan<>'')"

Write-Host "=== PER AKUN PERSEDIAAN: Physical(sinv) vs Own(GL) saldo awal 2026 ==="
Write-Host ("  {0,-10} {1,20} {2,20} {3,20}" -f 'Akun','Physical(sinv)','Own(GL)','Konsinyasi(selisih)')
$rows = Rows @"
select p.acc, cast(p.gl as numeric(18,2)) gl, cast(isnull(sv.stok,0) as numeric(18,2)) stok
from (select accountcode acc, sum(amountdebet-amountcredit) gl from gl_balance where site_id='101' and period='2026-01-01' and accountcode in $accIn group by accountcode) p
 left join (select gr.persediaan acc, sum(sv.nilai) stok from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='2026-01-01' group by gr.persediaan) sv on sv.acc=p.acc
"@
$tp=0;$tg=0
$rows | Sort-Object { -([decimal]$_.stok - [decimal]$_.gl) } | ForEach-Object {
  $cons=[decimal]$_.stok - [decimal]$_.gl; $tp+=[decimal]$_.stok; $tg+=[decimal]$_.gl
  Write-Host ("  {0,-10} {1,20:N2} {2,20:N2} {3,20:N2}" -f $_.acc,[decimal]$_.stok,[decimal]$_.gl,$cons)
}
Write-Host ("  {0,-10} {1,20:N2} {2,20:N2} {3,20:N2}" -f '=TOTAL=',$tp,$tg,($tp-$tg))

# Rincian per-item utk akun dgn konsinyasi > 1jt -> CSV
$big = ($rows | Where-Object { ([decimal]$_.stok - [decimal]$_.gl) -gt 1000000 } | ForEach-Object { "'"+$_.acc+"'" }) -join ','
Write-Host "`n=== Rincian per-item (akun konsinyasi >1jt) -> CSV ==="
if($big){
  $items = Rows @"
select gr.persediaan akun, sv.stok_id, left(max(pr.produk_desc),40) nm, cast(sum(sv.qty) as numeric(18,2)) qty, cast(sum(sv.nilai) as numeric(18,2)) nilai
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan in ($big) and sv.periode='2026-01-01' and sv.qty<>0 group by gr.persediaan, sv.stok_id
"@
  $obj = $items | ForEach-Object { [pscustomobject]@{ akun=$_.akun; stok_id=$_.stok_id; nama=$_.nm; qty=$_.qty; nilai=$_.nilai } }
  $csv="C:\BTV\debug\KONSINYASI_saldoawal2026_perItem.csv"
  $obj | Sort-Object akun, { -[decimal]$_.nilai } | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
  Write-Host "  CSV: $csv  (item ber-qty di akun terdampak)"
}
$P.Close()
