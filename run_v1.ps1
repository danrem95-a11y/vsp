$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== V1a: IM_PRODUCT_GROUP mapping (nama & persediaan) utk grup diawali L ==="
Reader "select KODE_GROUP, NAMA_GROUP, PERSEDIAAN from IM_PRODUCT_GROUP where NAMA_GROUP like 'L%' or PERSEDIAAN='102-110' order by PERSEDIAAN,NAMA_GROUP"

Write-Host "=== V1b: SINV(2026-04-01) opening per NAMA_GROUP utk akun 102-110 ==="
Reader "select g.NAMA_GROUP, g.KODE_GROUP, cast(sum(s.NILAI) as numeric(18,2)) opening_rp, count(*) n from SINV s, IM_PRODUK p, IM_PRODUCT_GROUP g where s.PERIODE='2026-04-01' and s.STOK_ID=p.PRODUK_ID and p.GROUP_PRODUCT=g.KODE_GROUP and g.PERSEDIAAN='102-110' group by g.NAMA_GROUP,g.KODE_GROUP order by opening_rp desc"

Write-Host "=== V1c: total opening 102-110 (semua grup di akun ini) ==="
Reader "select cast(sum(s.NILAI) as numeric(18,2)) total_opening from SINV s, IM_PRODUK p, IM_PRODUCT_GROUP g where s.PERIODE='2026-04-01' and s.STOK_ID=p.PRODUK_ID and p.GROUP_PRODUCT=g.KODE_GROUP and g.PERSEDIAAN='102-110'"

Write-Host "=== V1d: apakah ada NAMA_GROUP='LA' & akun-nya? + opening LA ==="
Reader "select g.NAMA_GROUP,g.KODE_GROUP,g.PERSEDIAAN, cast(sum(s.NILAI) as numeric(18,2)) opening_rp from SINV s, IM_PRODUK p, IM_PRODUCT_GROUP g where s.PERIODE='2026-04-01' and s.STOK_ID=p.PRODUK_ID and p.GROUP_PRODUCT=g.KODE_GROUP and g.NAMA_GROUP='LA' group by g.NAMA_GROUP,g.KODE_GROUP,g.PERSEDIAAN"
$cn.Close()
