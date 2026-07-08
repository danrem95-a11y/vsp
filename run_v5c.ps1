$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "===================== QUERY 3refined : hrg < -1e8 (tanda korupsi) SELURUH DB ====================="
Reader "select t2.stok_id, t1.tgl, t1.bukti_id, t1.tipe_trans, cast(t2.qty as numeric(18,2)) qty, cast(t2.hrg as numeric(18,2)) hrg, cast(t2.netto_hpp as numeric(18,2)) netto_hpp from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t2.hrg < -100000000 order by t1.tgl, t2.stok_id"

Write-Host "===================== QUERY 3b : ringkas hrg<-1e8 per stok & rentang tgl ====================="
Reader "select t2.stok_id, t1.tipe_trans, count(*) n, min(t1.tgl) first_tgl, max(t1.tgl) last_tgl from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t2.hrg < -100000000 group by t2.stok_id, t1.tipe_trans order by t2.stok_id"

Write-Host "===================== QUERY 5 : cek hpp=hrg utk '19' (LC&LF) & netto_hpp=round(hrg*qty) ====================="
Reader "select t2.stok_id, t1.tipe_trans, count(*) n, sum(case when t2.hpp=t2.hrg then 1 else 0 end) n_hpp_eq_hrg, sum(case when abs(t2.netto_hpp - round(t2.hrg*t2.qty,2))<0.05 then 1 else 0 end) n_nhpp_eq from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t2.stok_id in('LC.12.0012','LF.05.0002') and t1.tgl between '2026-01-01' and '2026-06-30' group by t2.stok_id, t1.tipe_trans order by t2.stok_id, t1.tipe_trans"

Write-Host "===================== QUERY 6 : apakah tipe '02' pernah negatif (hrg<0 atau netto_hpp<0)? SELURUH DB ====================="
Reader "select count(*) n_neg_02 from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and (t2.hrg<0 or t2.netto_hpp<0)"
Write-Host "--- distribusi netto_hpp '02' (harusnya 0) ---"
Reader "select case when t2.netto_hpp=0 then 'nol' when t2.netto_hpp>0 then 'positif' else 'NEGATIF' end kelas, count(*) n from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and t1.tgl between '2026-01-01' and '2026-06-30' group by case when t2.netto_hpp=0 then 'nol' when t2.netto_hpp>0 then 'positif' else 'NEGATIF' end"
$cn.Close()
