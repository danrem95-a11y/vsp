$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

# derived per-stok April '19'
$base = "(select t2.stok_id sid, sum(abs(t2.qty)) qty19, sum(abs(t2.netto_hpp)) snhpp from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='19' and t1.tgl between '2026-04-01' and '2026-04-30' and isnull(t1.order_oke,'N')='Y' group by t2.stok_id) a left outer join SINV sv on (sv.stok_id=a.sid and sv.periode='2026-05-01')"
$ratio = "(case when sv.qty is null or abs(sv.qty)<0.005 then 999999999 else a.qty19/abs(sv.qty) end)"

Write-Host "===== Q1/2/3/5 : KANDIDAT ratio>1 (semua kolom + status) ====="
$q1="select a.sid, cast(sv.qty as numeric(18,2)) qty_mei, cast(a.qty19 as numeric(18,2)) qty19_apr, cast($ratio as numeric(18,2)) ratio, cast(a.snhpp as numeric(18,2)) sum_netto_hpp, cast(sv.nilai as numeric(18,2)) nilai_mei, cast(sv.hpp_avg as numeric(18,2)) hpp_avg_mei, case when a.sid in('LC.12.0012','LF.05.0002','TL.107-0334') then 'SUDAH RUSAK' else 'NORMAL' end status from $base where $ratio > 1 order by $ratio desc"
Reader $q1

Write-Host "===== Q4 : DISTRIBUSI ratio (jumlah SKU per bucket) ====="
$q4="select bucket, count(*) n_sku from (select case when $ratio<0.5 then '1) <0.5' when $ratio<1 then '2) 0.5-1' when $ratio<2 then '3) 1-2' when $ratio<5 then '4) 2-5' else '5) >=5' end bucket from $base) x group by bucket order by bucket"
Reader $q4

Write-Host "===== total SKU punya '19' April & jumlah ratio>1 ====="
Reader "select count(*) total_sku_19, sum(case when $ratio>1 then 1 else 0 end) n_ratio_gt1 from $base"
$cn.Close()
