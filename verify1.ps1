$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== SINV total nilai per periode 2026 (saldo awal tiap bln = saldo akhir bln sblm) ==="
Reader "select periode, count(*) baris, sum(nilai) total_nilai, sum(qty) total_qty from sinv where periode between '2026-01-01' and '2026-08-01' group by periode order by periode"
Write-Host "`n=== kolom gl_journal ==="
$c=$cn.CreateCommand(); $c.CommandText="select * from gl_journal where 1=0"; $rd=$c.ExecuteReader()
$cols=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$cols+=$rd.GetName($i)}; $rd.Close(); Write-Host ("  "+($cols -join ", "))
Write-Host "`n=== akun persediaan (coa 102) - cari tabel coa ==="
Reader "select table_name from SYS.SYSTABLE where lower(table_name) like '%coa%' or lower(table_name) like '%perkiraan%' order by table_name"
$cn.Close()
