$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs
try{$cn.Open()}catch{Write-Host ("CONNECT ERR: "+$_.Exception.Message);exit}
Write-Host "CONNECTED`n"
function Exec($label,$sql){
  $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  $sw=[Diagnostics.Stopwatch]::StartNew()
  try{ $c.ExecuteNonQuery() | Out-Null; $sw.Stop(); Write-Host ("OK  [{0}]  {1} ms" -f $label,$sw.ElapsedMilliseconds) }
  catch{ $sw.Stop(); Write-Host ("SKIP/ERR [{0}] : {1}" -f $label,$_.Exception.Message) }
}
# PK TSALES1
Write-Host "=== PK/keycols TSALES1 ==="
$c=$cn.CreateCommand()
$c.CommandText="select scol.column_name from SYS.SYSCOLUMN scol join SYS.SYSTABLE stab on stab.table_id=scol.table_id where stab.table_name='tsales1' and scol.pkey='Y'"
try{$rd=$c.ExecuteReader(); $pk=@(); while($rd.Read()){$pk+=$rd[0]}; $rd.Close(); if($pk.Count -eq 0){Write-Host "  (tidak ada PK)"}else{Write-Host ("  PK = "+($pk -join ", "))} }
catch{Write-Host ("  pk err: "+$_.Exception.Message); $pk=@()}

Write-Host "`n=== CREATE INDEX ==="
Exec "idx_tsales1_tgl (tgl,tipe_trans)" "create index idx_tsales1_tgl on tsales1(tgl, tipe_trans)"
if( ($pk -join ',').ToLower() -notmatch 'bukti_id' ){
  Exec "idx_tsales1_bukti (bukti_id)" "create index idx_tsales1_bukti on tsales1(bukti_id)"
} else {
  Write-Host "  (bukti_id sudah PK TSALES1 -> tak perlu index tambahan)"
}
$cn.Close(); Write-Host "`nDONE"
