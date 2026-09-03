$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $cmd=$cn.CreateCommand(); $cmd.CommandTimeout=200; $cmd.CommandText=$sql
  try{$rd=$cmd.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
Qry "1 HPP jual (HARAP 38.5jt)" "select cast(isnull(hpp,0) as numeric(18,2)) hpp_jual from tsales2 where bukti_id='10126062200169' and stok_id='NR.201A'"
Qry "2 COGS GL 402-008 (HARAP 38.5jt)" "select cast(isnull(sum(debet),0) as numeric(18,2)) cogs from gl_journal where posting='P' and modul_id='HP' and account_id='402-008' and doc_reff='10106260600001'"
Qry "3 WIP-In tstok2 (HARAP 38.5jt)" "select cast(isnull(netto,0) as numeric(18,2)) netto, cast(isnull(hpp,0) as numeric(18,2)) hpp from tstok2 where bukti_id='10226062200169' and stok_id='NR.201A'"
Qry "4 Saldo akhir SINV NR.201A (HARAP qty=0 nilai=0)" "select periode, cast(isnull(qty,0) as numeric(18,2)) qty, cast(isnull(nilai,0) as numeric(18,2)) nilai from sinv where stok_id='NR.201A' and periode in ('2026-07-01','2026-08-01') order by periode"
$cn.Close()
