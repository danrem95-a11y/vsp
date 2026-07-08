$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
function Cols($tbl){ $t=$cn.GetSchema("Columns", @($null,$null,$tbl,$null)); $names=@(); foreach($r in ($t.Rows|Sort-Object {[int]$_["ORDINAL_POSITION"]})){ $names+=$r["COLUMN_NAME"]+"("+$r["TYPE_NAME"]+")" }; Write-Host ("  "+$tbl+": "+($names -join ", ")) }

Write-Host "===================== QUERY 7 : field audit ====================="
Cols "SINV"
Write-Host "  (TSTOK1 audit-ish: USER_ID, NEW_RATE_TGL, NEW_RATE_TGL ; TSTOK2: tidak ada timestamp)"

Write-Host "===================== QUERY 1 : transaksi urut waktu (LC & LF) ====================="
$q1="select t2.stok_id, t1.tgl, t1.user_id, t1.bukti_id, t2.urut, t1.tipe_trans, cast(t2.qty as numeric(18,2)) qty, cast(t2.hrg as numeric(18,2)) hrg, cast(t2.hpp as numeric(18,2)) hpp, cast(t2.netto as numeric(18,2)) netto, cast(t2.netto_hpp as numeric(18,2)) netto_hpp from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t2.stok_id in('LC.12.0012','LF.05.0002') and t1.tgl between '2026-01-01' and '2026-06-30' order by t2.stok_id, t1.tgl, t1.bukti_id, t2.urut"
Reader $q1

Write-Host "===================== QUERY 2 : distinct HRG (LC & LF) Jan-Jun ====================="
Reader "select t2.stok_id, cast(t2.hrg as numeric(18,2)) hrg, count(*) n, min(t1.tgl) first_tgl, max(t1.tgl) last_tgl from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t2.stok_id in('LC.12.0012','LF.05.0002') and t1.tgl between '2026-01-01' and '2026-06-30' group by t2.stok_id, t2.hrg order by t2.stok_id, hrg"

Write-Host "===================== QUERY 3 : SEMUA transaksi |hrg|>1e8 (seluruh DB) ====================="
Reader "select t2.stok_id, t1.tgl, t1.bukti_id, t1.tipe_trans, cast(t2.qty as numeric(18,2)) qty, cast(t2.hrg as numeric(18,2)) hrg from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and abs(t2.hrg)>100000000 order by t1.tgl, t2.stok_id"

Write-Host "===================== QUERY 4 : SKU pola identik |hrg|>1e8 atau |netto_hpp|>1e8 (Apr-Mei) ====================="
Reader "select t2.stok_id, count(*) n, cast(sum(abs(t2.netto_hpp)) as numeric(18,2)) sum_nhpp, min(t1.tgl) first_tgl, max(t1.tgl) last_tgl from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and (abs(t2.hrg)>100000000 or abs(t2.netto_hpp)>100000000) and t1.tgl between '2026-04-01' and '2026-05-31' group by t2.stok_id order by sum_nhpp desc"
$cn.Close()
