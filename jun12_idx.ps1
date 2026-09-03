$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

foreach($t in 'gl_journal','tsales1','tsales2','tstok1','tstok2','tbyr1','tbyr2'){
  Write-Host ("`n=== INDEX $t ===")
  Reader @"
select ix.index_name, ix."unique",
  (select list(sc.column_name order by ic.sequence)
     from SYS.SYSIXCOL ic join SYS.SYSCOLUMN sc on sc.table_id=ic.table_id and sc.column_id=ic.column_id
     where ic.table_id=ix.table_id and ic.index_id=ix.index_id) cols
from SYS.SYSINDEX ix join SYS.SYSTABLE t on t.table_id=ix.table_id
where t.table_name='$t'
order by ix.index_name
"@
}

Write-Host "`n=== PRIMARY KEY kolom (SYSCOLUMN pkey) tabel panas ==="
Reader @"
select t.table_name, list(c.column_name order by c.column_id) pk
from SYS.SYSCOLUMN c join SYS.SYSTABLE t on t.table_id=c.table_id
where t.table_name in ('gl_journal','tsales2','tstok2','tbyr2') and c.pkey='Y'
group by t.table_name
"@

$cn.Close()
