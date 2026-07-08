$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

foreach($acc in @('102-101','102-102','102-110')){
  Write-Host ("############ AKUN "+$acc+" ############")
  Write-Host "=== GL April per modul (net=debet-kredit) ==="
  Reader ("select modul_id, count(*) n, cast(sum(debet-kredit) as numeric(18,2)) net from GL_JOURNAL where account_id='"+$acc+"' and tgl between '2026-04-01' and '2026-04-30' and posting='P' group by modul_id order by modul_id")
}

Write-Host "=== '19' April per akun (netto_hpp bersih sekarang) ==="
Reader "select g.persediaan acc, count(*) n, cast(sum(abs(t2.netto_hpp)) as numeric(18,2)) sum_19 from TSTOK1 t1,TSTOK2 t2, IM_PRODUK p, IM_PRODUCT_GROUP g where t1.bukti_id=t2.bukti_id and t2.stok_id=p.produk_id and p.group_product=g.kode_group and t1.tipe_trans='19' and t1.tgl between '2026-04-01' and '2026-04-30' and g.persediaan in('102-101','102-102','102-110') group by g.persediaan order by g.persediaan"

Write-Host "=== EVAP jual_by_evap April per akun (nilai) - potensi beda basis ==="
Reader "select g.persediaan acc, count(*) n, cast(sum(abs(t2.qty*isnull(t2.hpp,0))) as numeric(18,2)) evap_nilai from TSALES1 t1,TSALES2 t2, IM_PRODUK p, IM_PRODUCT_GROUP g where t1.bukti_id=t2.bukti_id and t2.stok_id=p.produk_id and p.group_product=g.kode_group and t1.tipe_trans='22' and isnull(t2.evap,'')<>'' and t1.tgl between '2026-04-01' and '2026-04-30' and g.persediaan in('102-101','102-102','102-110') group by g.persediaan order by g.persediaan"
$cn.Close()
