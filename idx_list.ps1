$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs
try{$cn.Open()}catch{Write-Host ("CONNECT ERR: "+$_.Exception.Message);exit}
Write-Host "CONNECTED`n=== INDEX yang sudah ada di tsales1/tsales2/sinv/tstok1/tstok2 ==="
$sql = @"
select stab.table_name, sidx.index_name, scol.column_name, sixc.sequence
from SYS.SYSINDEX sidx
join SYS.SYSTABLE stab on stab.table_id = sidx.table_id
join SYS.SYSIXCOL sixc on sixc.table_id = sidx.table_id and sixc.index_id = sidx.index_id
join SYS.SYSCOLUMN scol on scol.table_id = sixc.table_id and scol.column_id = sixc.column_id
where stab.table_name in ('tsales1','tsales2','sinv','tstok1','tstok2')
order by stab.table_name, sidx.index_name, sixc.sequence
"@
$c=$cn.CreateCommand(); $c.CommandText=$sql
try{
  $rd=$c.ExecuteReader()
  while($rd.Read()){ Write-Host ("  {0,-9} idx={1,-28} col={2} seq={3}" -f $rd[0],$rd[1],$rd[2],$rd[3]) }
  $rd.Close()
}catch{ Write-Host ("  LIST ERR: "+$_.Exception.Message) }
$cn.Close()
