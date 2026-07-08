$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Go($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql; $c.ExecuteNonQuery()|Out-Null }
try{
  Go "set temporary option blocking = 'On'"
  Go "set temporary option blocking_timeout = '45000'"   # antre lock sampai 45 detik
  Write-Host "blocking=On, timeout=45s. Membuat index (akan menunggu celah lock)..."
  $sw=[Diagnostics.Stopwatch]::StartNew()
  Go "create index idx_tsales1_tgl on tsales1(tgl, tipe_trans)"
  $sw.Stop()
  Write-Host ("OK  idx_tsales1_tgl dibuat dalam {0} ms" -f $sw.ElapsedMilliseconds)
}catch{ Write-Host ("GAGAL: "+$_.Exception.Message) }
# verifikasi
$c=$cn.CreateCommand(); $c.CommandText="select count(*) from SYS.SYSINDEX i join SYS.SYSTABLE t on t.table_id=i.table_id where t.table_name='tsales1' and i.index_name='idx_tsales1_tgl'"
Write-Host ("Verifikasi ada index: "+$c.ExecuteScalar())
$cn.Close()
