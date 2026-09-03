$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== ID DB ==="
Reader "select db_name() dbname, property('Name') eng"

Write-Host "`n=== SINV periode 2026 (apakah Juni sudah close -> ada 2026-07-01?) ==="
Reader "select periode, count(*) n, cast(sum(nilai) as numeric(18,2)) total from sinv where periode >= '2026-01-01' group by periode order by periode"

Write-Host "`n=== Akun PERSEDIAAN (im_product_group) ==="
Reader "select persediaan, count(*) n_group from im_product_group where persediaan is not null and persediaan <> '' group by persediaan order by persediaan"

Write-Host "`n=== gl_journal Juni: rentang tgl & jumlah baris per posting ==="
Reader "select posting, count(*) n, cast(sum(debet) as numeric(18,0)) debet, cast(sum(kredit) as numeric(18,0)) kredit from gl_journal where tgl between '2026-06-01' and '2026-06-30' group by posting"

$cn.Close()
