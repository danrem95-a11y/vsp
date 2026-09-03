$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

$items = "('TR.1010A','NDS.12.1.12.0009','LC.06.0001','LA.06.0018','TS.044-6918Z','LI.01.0004','LD.02.0020')"

Qry "7 item: qty Apr vs Mei + jumlah transaksi April (IN=tstok, OUT=tsales)" @"
select v.stok_id,
  cast(a.qty as numeric(18,2)) qty_apr, cast(b.qty as numeric(18,2)) qty_mei,
  cast(b.nilai-a.nilai as numeric(18,2)) delta_nilai,
  (select count(*) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t2.stok_id=v.stok_id and t1.tgl between '2026-04-01' and '2026-04-30') n_in,
  cast((select isnull(sum(t2.qty),0) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t2.stok_id=v.stok_id and t1.tgl between '2026-04-01' and '2026-04-30') as numeric(18,2)) qty_in,
  (select count(*) from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id where s2.stok_id=v.stok_id and s1.tgl between '2026-04-01' and '2026-04-30') n_out,
  cast((select isnull(sum(s2.qty),0) from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id where s2.stok_id=v.stok_id and s1.tgl between '2026-04-01' and '2026-04-30') as numeric(18,2)) qty_out
from (select distinct stok_id from sinv where stok_id in $items) v
join sinv a on a.stok_id=v.stok_id and a.periode='2026-04-01'
join sinv b on b.stok_id=v.stok_id and b.periode='2026-05-01'
order by abs(b.nilai-a.nilai) desc
"@

Qry "TR.1010A: jejak sinv sepanjang 2026 (lihat kapan hpp bergeser)" @"
select cast(periode as date) periode, cast(qty as numeric(18,2)) qty, cast(hpp_avg as numeric(18,2)) hpp_avg, cast(nilai as numeric(18,2)) nilai
from sinv where stok_id='TR.1010A' and periode between '2026-01-01' and '2026-08-01' order by periode
"@
$cn.Close()
