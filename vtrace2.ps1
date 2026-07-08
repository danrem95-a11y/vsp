$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
foreach($s in @('LC.12.0012','LF.05.0002','TL.107-0334')){
  Write-Host ("=== $s : SINV Apr(04/01) & Mei(05/01) ===")
  Reader "select periode, cast(qty as numeric(18,2)) qty, cast(hpp_avg as numeric(18,2)) hpp, cast(nilai as numeric(18,0)) nilai from sinv where stok_id='$s' and periode in ('2026-04-01','2026-05-01')"
  Write-Host ("--- $s : tstok2 April per tipe_trans ---")
  Reader "select a.tipe_trans, count(*) n, cast(sum(b.qty) as numeric(18,2)) qty, cast(sum(b.netto) as numeric(18,0)) netto, cast(sum(b.netto_hpp) as numeric(18,0)) netto_hpp, cast(max(b.hpp) as numeric(18,0)) max_hpp from tstok1 a, tstok2 b where a.bukti_id=b.bukti_id and b.stok_id='$s' and a.tgl between '2026-04-01' and '2026-04-30' group by a.tipe_trans"
}
$cn.Close()
