$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "sysgroupleftmenu utk item FA 6230 (Generate Penyusutan) - grant per group" "select usergroup,itemid,s_view,s_add,s_edit,s_delete,s_cetak,s_alldata,s_koreksi,s_harga from sysgroupleftmenu where itemid='6230' order by usergroup"
Qry "berapa group punya akses FA 6230 vs total group" "select (select count(*) from sysgroupleftmenu where itemid='6230') punya_6230, (select count(distinct usergroup) from sysgroupleftmenu) total_group"
Qry "tipe kolom sysleftmenu" "select c.column_name, c.nulls, (select d.domain_name from sysdomain d where d.domain_id=c.domain_id) tipe, c.width from syscolumn c join systable t on t.table_id=c.table_id where t.table_name='sysleftmenu' order by c.column_id"
Qry "tipe kolom sysgroupleftmenu" "select c.column_name, c.nulls, (select d.domain_name from sysdomain d where d.domain_id=c.domain_id) tipe, c.width from syscolumn c join systable t on t.table_id=c.table_id where t.table_name='sysgroupleftmenu' order by c.column_id"
$cn.Close()
