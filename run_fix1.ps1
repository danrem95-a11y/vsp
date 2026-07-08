$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== A: hpp_avg BERSIH awal-April (2026-04-01) utk 4 SKU ==="
Reader "select stok_id, cast(hpp_avg as numeric(18,4)) hpp_awal_apr, cast(qty as numeric(18,2)) qty, cast(nilai as numeric(18,2)) nilai from SINV where periode='2026-04-01' and stok_id in('LC.12.0012','LF.05.0002','TL.107-0334','TS.066-8344C') order by stok_id"

Write-Host "=== B: SEMUA baris '19' RUSAK (hrg<0) yg perlu direpair : bukti_id,urut,qty,hrg skrg ==="
Reader "select t2.stok_id, t1.bukti_id, t2.urut, t1.tgl, cast(t2.qty as numeric(18,2)) qty, cast(t2.hrg as numeric(18,2)) hrg_now, cast(t2.netto as numeric(18,2)) netto_now, cast(t2.netto_hpp as numeric(18,2)) nhpp_now from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t2.hrg<0 and t1.tipe_trans='19' order by t2.stok_id, t1.tgl"

Write-Host "=== C: SINV periode 2026-05-01 (yg akan dikoreksi) utk 4 SKU ==="
Reader "select stok_id, cast(qty as numeric(18,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(18,2)) hpp_avg from SINV where periode='2026-05-01' and stok_id in('LC.12.0012','LF.05.0002','TL.107-0334','TS.066-8344C') order by stok_id"

Write-Host "=== D: GL 'AS' postingan '19'-korup terkait (per akun & keterangan besar) ==="
Reader "select account_id, count(*) n, cast(sum(kredit) as numeric(18,2)) sum_kredit from GL_JOURNAL where modul_id='AS' and tgl between '2026-04-01' and '2026-04-30' and posting='P' and kredit>100000000 group by account_id order by sum_kredit desc"
$cn.Close()
