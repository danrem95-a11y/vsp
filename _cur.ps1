$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$c=$cn.CreateCommand(); $c.CommandText="select gr.PERSEDIAAN acc, cast(sum(s.nilai) as numeric(18,0)) sinv_nyata from sinv s join im_produk p on p.produk_id=s.stok_id join IM_PRODUCT_GROUP gr on gr.KODE_GROUP=p.group_product where gr.PERSEDIAAN in ('102-001','102-110') and s.periode='2026-05-01' group by gr.PERSEDIAAN order by gr.PERSEDIAAN"
$rd=$c.ExecuteReader(); while($rd.Read()){Write-Host ("  "+$rd[0]+" | sinv_nyata="+$rd[1])}; $rd.Close(); $cn.Close()
