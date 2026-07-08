$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Scalar($sql){ $c=$cn.CreateCommand(); $c.CommandText=$sql; return $c.ExecuteScalar() }
function Go($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql; $c.ExecuteNonQuery()|Out-Null }
Write-Host ("Sisa lock TSALES1 sebelum create: " + (Scalar "select count(*) from sa_locks() where lower(table_name) like '%tsales1%'"))
try{
  $sw=[Diagnostics.Stopwatch]::StartNew()
  Go "create index idx_tsales1_tgl on tsales1(tgl, tipe_trans)"
  $sw.Stop(); Write-Host ("OK  idx_tsales1_tgl dibuat dalam {0} ms" -f $sw.ElapsedMilliseconds)
}catch{ Write-Host ("GAGAL: "+($_.Exception.Message -replace '.*Anywhere\]','')) }
Write-Host ("Verifikasi index ada: " + (Scalar "select count(*) from SYS.SYSINDEX i join SYS.SYSTABLE t on t.table_id=i.table_id where t.table_name='tsales1' and i.index_name='idx_tsales1_tgl'"))
Write-Host "`n=== kolom index idx_tsales1_tgl ==="
$c=$cn.CreateCommand(); $c.CommandText="select scol.column_name, sixc.sequence from SYS.SYSINDEX sidx join SYS.SYSTABLE stab on stab.table_id=sidx.table_id join SYS.SYSIXCOL sixc on sixc.table_id=sidx.table_id and sixc.index_id=sidx.index_id join SYS.SYSCOLUMN scol on scol.table_id=sixc.table_id and scol.column_id=sixc.column_id where stab.table_name='tsales1' and sidx.index_name='idx_tsales1_tgl' order by sixc.sequence"
$rd=$c.ExecuteReader(); while($rd.Read()){ Write-Host ("  "+$rd[0]+" seq="+$rd[1]) }; $rd.Close()
$cn.Close()
