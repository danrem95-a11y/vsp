$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Reader($s){ $c=$cn.CreateCommand();$c.CommandTimeout=120;$c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR:"+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("  "+($l -join " | "))};$rd.Close() }
foreach($t in @('TSALES1','TSALES2','TSTOK1','TSTOK2')){
  Write-Host ("=== index "+$t+" ===")
  Reader ("select i.index_name, t2.column_name, ixc.sequence from sys.systable t join sys.sysidx i on t.table_id=i.table_id join sys.sysidxcol ixc on i.table_id=ixc.table_id and i.index_id=ixc.index_id join sys.syscolumn t2 on ixc.table_id=t2.table_id and ixc.column_id=t2.column_id where t.table_name='"+$t+"' order by i.index_name, ixc.sequence")
}
Write-Host "=== jumlah baris TSALES1/TSTOK1 (April) ==="
Reader "select 'tsales1_apr', count(*) from tsales1 where tgl between '2026-04-01' and '2026-04-30'"
Reader "select 'tstok1_apr', count(*) from tstok1 where tgl between '2026-04-01' and '2026-04-30'"
Reader "select 'tsales1_total', count(*) from tsales1"
$cn.Close()
