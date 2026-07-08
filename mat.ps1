$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Qry($s){$c=$cn.CreateCommand();$c.CommandTimeout=200;$c.CommandText=$s;$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
Write-Host "=== gl_balance 102-201 semua tahun (saldo awal per tahun) ==="
Qry "select Period, cast(AmountDebet-AmountCredit as numeric(18,2)) opening, site_id from gl_balance where AccountCode='102-201' order by Period"
Write-Host ""
Write-Host "=== SINV MT (MATERIAL TAMBAHAN) per periode 2024-2026 ==="
Qry "select s.periode, cast(sum(s.nilai) as numeric(18,2)) sinv, cast(sum(s.qty) as numeric(18,2)) qty from sinv s, im_produk p where s.stok_id=p.produk_id and p.group_product='MT' and s.periode between '2024-12-01' and '2026-01-01' group by s.periode order by s.periode"
Write-Host ""
Write-Host "=== GL 102-201 jurnal per TAHUN & modul (net=debet-kredit) ==="
Qry "select year(tgl) thn, modul_id, count(*) n, cast(sum(debet-kredit) as numeric(18,2)) net from gl_journal where account_id='102-201' and posting='P' group by year(tgl),modul_id order by thn,modul_id"
$cn.Close()
