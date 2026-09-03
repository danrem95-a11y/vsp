$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== Identitas (pastikan PROD) ==="
Reader "select db_name() dbname, property('Name') eng, property('CommandLine') cmd"

foreach($t in 'gl_journal','tsales1','tsales2','tstok1','tstok2','tbyr1','tbyr2'){
  Write-Host ("`n=== INDEX $t (PROD) ===")
  Reader @"
select ix.index_name,
  (select list(sc.column_name order by ic.sequence)
     from SYS.SYSIXCOL ic join SYS.SYSCOLUMN sc on sc.table_id=ic.table_id and sc.column_id=ic.column_id
     where ic.table_id=ix.table_id and ic.index_id=ix.index_id) cols
from SYS.SYSINDEX ix join SYS.SYSTABLE t on t.table_id=ix.table_id
where t.table_name='$t'
order by ix.index_name
"@
}

Write-Host "`n=== Waktu lookup gl_journal doc_reff / voucher_manual (prod) ==="
function Timed($label,$sql){ $c=$cn.CreateCommand(); $c.CommandText=$sql
  $sw=[System.Diagnostics.Stopwatch]::StartNew(); try{$v=$c.ExecuteScalar()}catch{Write-Host ("  "+$label+" ERR");return}; $sw.Stop()
  Write-Host ("  {0,-32} = {1,7:N0} ms (hasil={2})" -f $label,$sw.Elapsed.TotalMilliseconds,$v) }
$ord = (New-Object System.Data.Odbc.OdbcCommand("select top 1 doc_reff from gl_journal where tgl>='2026-06-01' and tgl<'2026-07-01' and doc_reff is not null",$cn)).ExecuteScalar()
Timed "doc_reff lookup" "select count(*) from gl_journal where doc_reff='$ord'"

$cn.Close()
