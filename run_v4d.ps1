$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== V4d1: per-unit '19' 102-110 : netto_hpp vs netto vs hrg (top 15 by |netto_hpp|) ==="
$q="select top 15 t2.stok_id, cast(sum(abs(t2.qty)) as numeric(18,2)) qty, cast(sum(abs(t2.netto_hpp)) as numeric(18,2)) sum_netto_hpp, cast(sum(abs(t2.netto)) as numeric(18,2)) sum_netto, cast(avg(t2.hrg) as numeric(18,2)) avg_hrg from TSTOK1 t1, TSTOK2 t2, IM_PRODUK p, IM_PRODUCT_GROUP g where t1.bukti_id=t2.bukti_id and t2.stok_id=p.produk_id and p.group_product=g.kode_group and g.persediaan='102-110' and t1.tgl between '2026-04-01' and '2026-04-30' and t1.order_oke='Y' and t1.tipe_trans='19' group by t2.stok_id order by sum_netto_hpp desc"
Reader $q

Write-Host "=== V4d2: pisah unit 'korup' (|netto_hpp|>1e8) vs 'bersih' di 102-110 '19' ==="
$q2="select case when u.snhpp>100000000 then 'KORUP(>1e8)' else 'bersih' end kelas, count(*) n_unit, cast(sum(u.snhpp) as numeric(18,2)) sum_netto_hpp, cast(sum(u.qty) as numeric(18,2)) qty from (select t2.stok_id, sum(abs(t2.netto_hpp)) snhpp, sum(abs(t2.qty)) qty from TSTOK1 t1, TSTOK2 t2, IM_PRODUK p, IM_PRODUCT_GROUP g where t1.bukti_id=t2.bukti_id and t2.stok_id=p.produk_id and p.group_product=g.kode_group and g.persediaan='102-110' and t1.tgl between '2026-04-01' and '2026-04-30' and t1.order_oke='Y' and t1.tipe_trans='19' group by t2.stok_id) u group by case when u.snhpp>100000000 then 'KORUP(>1e8)' else 'bersih' end"
Reader $q2
$cn.Close()
