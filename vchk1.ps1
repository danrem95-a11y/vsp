$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== (1) SINV total per periode 2026 (kondisi TERKINI) ==="
Reader "select periode, count(*) baris, cast(sum(nilai) as numeric(18,0)) total_nilai, cast(sum(qty) as numeric(18,2)) total_qty, sum(case when qty<0 then 1 else 0 end) qty_minus, cast(sum(case when nilai<0 then nilai else 0 end) as numeric(18,0)) nilai_negatif from sinv where periode between '2026-03-01' and '2026-07-01' group by periode order by periode"
Write-Host "`n=== (2) SINV Mei (05/01): produk qty<0 atau hpp<0 (harusnya 0 kalau al_minus jalan) ==="
Reader "select top 10 stok_id, cast(qty as numeric(18,2)) qty, cast(hpp_avg as numeric(18,2)) hpp, cast(nilai as numeric(18,0)) nilai from sinv where periode='2026-05-01' and (qty<0 or hpp_avg<0 or nilai<0) order by nilai"
Write-Host "`n=== (3) WIP OUT April: tsales1.tipe_trans='88' -> qty vs hpp (kenapa Rp kosong) ==="
Reader "select count(*) baris, cast(sum(b.qty) as numeric(18,2)) sum_qty, cast(sum(b.hpp*b.qty) as numeric(18,0)) sum_hppxqty, sum(case when isnull(b.hpp,0)=0 and b.qty<>0 then 1 else 0 end) qty_tanpa_hpp from tsales1 a, tsales2 b where a.bukti_id=b.bukti_id and a.tipe_trans='88' and a.tgl between '2026-04-01' and '2026-04-30'"
$cn.Close()
