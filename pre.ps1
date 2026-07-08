$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Qry($s){$c=$cn.CreateCommand();$c.CommandText=$s;$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
Write-Host "=== jurnal GL Mei 2026 (posting P) per modul ==="
Qry "select modul_id, count(*) n, cast(sum(debet-kredit) as numeric(18,2)) net from gl_journal where tgl between '2026-05-01' and '2026-05-31' and posting='P' and account_id like '102-%' group by modul_id order by modul_id"
Write-Host "=== periode SINV yang ada di sekitar Mei ==="
Qry "select periode, count(*) n from sinv where periode in ('2026-05-01','2026-06-01') group by periode order by periode"
Write-Host "=== transaksi stok/sales Mei ada? ==="
Qry "select 'tstok1_mei' t, count(*) n from tstok1 where tgl between '2026-05-01' and '2026-05-31'"
Qry "select 'tsales1_mei' t, count(*) n from tsales1 where tgl between '2026-05-01' and '2026-05-31'"
$cn.Close()
