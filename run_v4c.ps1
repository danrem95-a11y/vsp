$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== L3c: irisan bukti_reff '19' vs '09' (April) ==="
Reader "select count(*) shared_reff from (select distinct bukti_reff br from TSTOK1 where tipe_trans='19' and tgl between '2026-04-01' and '2026-04-30') a, (select distinct bukti_reff br from TSTOK1 where tipe_trans='09' and tgl between '2026-04-01' and '2026-04-30') b where a.br=b.br and a.br<>''"

Write-Host "=== L4a: total '19' vs '09' April SEMUA akun (detail,qty,netto,netto_hpp) ==="
Reader "select t1.tipe_trans, count(*) n_det, cast(sum(abs(t2.qty)) as numeric(18,2)) qty, cast(sum(abs(t2.netto)) as numeric(18,2)) netto, cast(sum(abs(t2.netto_hpp)) as numeric(18,2)) netto_hpp from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans in('19','09') and t1.tgl between '2026-04-01' and '2026-04-30' group by t1.tipe_trans order by t1.tipe_trans"

Write-Host "=== L4b: sampel detail 1 header '19' (bukti 10126041900001) ==="
Reader "select t2.stok_id, cast(t2.qty as numeric(18,2)) qty, cast(t2.hrg as numeric(18,4)) hrg, cast(t2.netto as numeric(18,2)) netto, cast(t2.netto_hpp as numeric(18,2)) netto_hpp, t2.coa_id from TSTOK2 t2 where t2.bukti_id='10126041900001'"

Write-Host "=== L4c: distribusi COA_ID pada detail '19' April (lawan akun) ==="
Reader "select t2.coa_id, count(*) n, cast(sum(abs(t2.netto_hpp)) as numeric(18,2)) netto_hpp from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='19' and t1.tgl between '2026-04-01' and '2026-04-30' group by t2.coa_id order by netto_hpp desc"
$cn.Close()
