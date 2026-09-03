$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=localhost;port=2638);Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs
try{$cn.Open()}catch{Write-Host ("OPEN ERR: "+$_.Exception.Message);exit}
$c=$cn.CreateCommand();$c.CommandTimeout=60
$c.CommandText=@"
select db_name() dbname, property('Name') eng, db_property('File') dbfile,
 (select count(*) from sinv where periode='2026-02-01') sinv_jan,
 (select count(*) from sinv where periode='2026-03-01') sinv_feb,
 (select max(tgl) from gl_journal) gl_maxtgl
"@
$rd=$c.ExecuteReader()
while($rd.Read()){for($i=0;$i -lt $rd.FieldCount;$i++){Write-Host ($rd.GetName($i)+" = "+[string]$rd[$i])}}
$rd.Close();$cn.Close()
