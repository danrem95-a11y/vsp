$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$c=$cn.CreateCommand(); $c.CommandTimeout=120
$c.CommandText="select cast(sum(debet) as numeric(18,2)) tot_debet, cast(sum(kredit) as numeric(18,2)) tot_kredit, cast(sum(debet)-sum(kredit) as numeric(18,2)) selisih from gl_journal where posting='P' and tgl>='2026-06-01' and tgl<'2026-07-01'"
$rd=$c.ExecuteReader()
while($rd.Read()){ Write-Host ("  debet="+$rd["tot_debet"]+"  kredit="+$rd["tot_kredit"]+"  selisih="+$rd["selisih"]) }
$rd.Close(); $cn.Close()
