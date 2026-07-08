$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
function Scalar($sql){ $c=$cn.CreateCommand(); $c.CommandText=$sql; try{return $c.ExecuteScalar()}catch{return "?"} }
Write-Host ("closing_sales (periode terakhir ter-closing) = " + (Scalar "select closing_sales from gl_setup"))
Write-Host "`n=== akun persediaan: account_id like 102% di gl_journal (2026) ==="
Reader "select account_id, count(*) baris, sum(debet) tot_debet, sum(kredit) tot_kredit from gl_journal where account_id like '102%' and posting='P' and tgl between '2026-01-01' and '2026-04-30' group by account_id order by account_id"
Write-Host "`n=== tabel gl_balance ada? kolomnya? ==="
Reader "select table_name from SYS.SYSTABLE where lower(table_name) like '%balance%' or lower(table_name)='gl_saldo' order by table_name"
Write-Host "`n=== master akun (cari tabel) ==="
Reader "select top 5 table_name from SYS.SYSTABLE where lower(table_name) in ('mperk','account','chart','glaccount','gl_account','mstacc','coa','mcoa','mst_coa') order by table_name"
$cn.Close()
