$conn=New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=60
$cmd.CommandText="SELECT db_name()"; $db=$cmd.ExecuteScalar()
$cmd.CommandText="SELECT db_property('File')"; $file=$cmd.ExecuteScalar()
$cmd.CommandText="SELECT property('MachineName')"; $host2=$cmd.ExecuteScalar()
"DB=$db  HOST=$host2  FILE=$file"
$cmd.CommandText=@"
SELECT a.order_client doc, a.ttl_kotor input,
 (SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id=a.order_client) tstok2,
 (SELECT SUM(isnull(ttl_netto,0)+isnull(freight,0)) FROM ap_trans c WHERE c.order_reff=a.order_client AND c.bukti_id<>a.order_client) anak,
 (SELECT SUM(debet) FROM gl_journal WHERE doc_reff=a.order_client AND modul_id='EX' AND account_id='102-101') gl_persediaan,
 (SELECT MAX(posting) FROM gl_journal WHERE doc_reff=a.order_client AND modul_id='EX') posting
FROM ap_trans a WHERE a.order_client IN ('10126040500001','10126040500002')
"@
$r=$cmd.ExecuteReader()
while($r.Read()){ "doc={0} input={1:N0} tstok2={2:N2} anak={3:N0} gl_persediaan={4:N0} posting={5}" -f $r['doc'],[decimal]$r['input'],[decimal]$r['tstok2'],[decimal]$r['anak'],[decimal]$r['gl_persediaan'],$r['posting'] }
$r.Close(); $conn.Close()
