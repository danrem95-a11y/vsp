$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== W1: group yang PERSEDIAAN=102-020 ==="
Reader "select KODE_GROUP, NAMA_GROUP, PERSEDIAAN from IM_PRODUCT_GROUP where PERSEDIAAN='102-020'"

Write-Host "=== W2: jumlah IM_PRODUK stok_item='Y' pd group tsb ==="
Reader "select g.NAMA_GROUP, count(*) n_produk, sum(case when p.stok_item='Y' then 1 else 0 end) n_stok_item from IM_PRODUK p, IM_PRODUCT_GROUP g where p.group_product=g.kode_group and g.persediaan='102-020' group by g.NAMA_GROUP"

Write-Host "=== W3: baris SINV utk stok di group 102-020 (semua periode) ==="
Reader "select count(*) n_sinv_rows, count(distinct s.stok_id) n_stok, cast(sum(s.nilai) as numeric(18,2)) tot_nilai from SINV s, IM_PRODUK p, IM_PRODUCT_GROUP g where s.stok_id=p.produk_id and p.group_product=g.kode_group and g.persediaan='102-020'"

Write-Host "=== W4: GL 102-020 April - komposisi per modul ==="
Reader "select modul_id, count(*) n, cast(sum(debet) as numeric(18,2)) sdeb, cast(sum(kredit) as numeric(18,2)) skre from GL_JOURNAL where account_id='102-020' and tgl between '2026-01-01' and '2026-04-30' and posting='P' group by modul_id order by modul_id"

Write-Host "=== W5: saldo GL 102-020 (opening + jrn s/d Apr) ==="
Reader "select cast((select sum(AmountDebet-AmountCredit) from GL_BALANCE where AccountCode='102-020' and Period='2026-01-01') + (select sum(debet-kredit) from GL_JOURNAL where account_id='102-020' and tgl between '2026-01-01' and '2026-04-30' and posting='P') as numeric(18,2)) saldo_gl_apr"
$cn.Close()
