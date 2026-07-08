$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Qry($s){$c=$cn.CreateCommand();$c.CommandTimeout=200;$c.CommandText=$s;$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
Write-Host "=== group utk 102-001 & 102-201 ==="
Qry "select kode_group,nama_group,persediaan,hpp from im_product_group where persediaan in ('102-001','102-201')"
Write-Host "=== GL per modul 102-001 (TR) April ==="
Qry "select modul_id,count(*) n,cast(sum(debet-kredit) as numeric(18,2)) net from gl_journal where account_id='102-001' and tgl between '2026-04-01' and '2026-04-30' and posting='P' group by modul_id order by modul_id"
Write-Host "=== GL per modul 102-201 (MAT) April ==="
Qry "select modul_id,count(*) n,cast(sum(debet-kredit) as numeric(18,2)) net from gl_journal where account_id='102-201' and tgl between '2026-04-01' and '2026-04-30' and posting='P' group by modul_id order by modul_id"
Write-Host "=== SINV(2026-05-01) per akun 102-001 & 102-201 (=sumber ledger) ==="
Qry "select g.persediaan, cast(sum(s.nilai) as numeric(18,2)) sinv_akhir, count(*) n from sinv s, im_produk p, im_product_group g where s.periode='2026-05-01' and s.stok_id=p.produk_id and p.group_product=g.kode_group and g.persediaan in ('102-001','102-201') group by g.persediaan"
$cn.Close()
