$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
Write-Host ("MyConn number = " + ($cn.CreateCommand() | % { $_.CommandText='select connection_property(''Number'')'; $_.ExecuteScalar() }))
function Go($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql; $c.ExecuteNonQuery()|Out-Null }
try{ Go "commit" }catch{}
try{
  $sw=[Diagnostics.Stopwatch]::StartNew()
  Go "create index idx_tsales1_tgl on tsales1(tgl, tipe_trans)"
  $sw.Stop(); Write-Host ("OK dibuat dalam {0} ms" -f $sw.ElapsedMilliseconds)
}catch{ Write-Host ("GAGAL: "+($_.Exception.Message -replace '.*Anywhere\]','')) }
$c=$cn.CreateCommand(); $c.CommandText="select count(*) from SYS.SYSINDEX i join SYS.SYSTABLE t on t.table_id=i.table_id where t.table_name='tsales1' and i.index_name='idx_tsales1_tgl'"
Write-Host ("index ada? "+$c.ExecuteScalar())
$cn.Close()
