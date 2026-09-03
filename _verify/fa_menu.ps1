$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "Menu FA (windowobject w_fa%)" "select groupid, groupdesc, itemid, itemdesc, itemparentid, windowobject from sysleftmenu where windowobject like 'w_fa%' order by itemid"
Qry "Semua item di GROUP FA (groupid sama dgn menu FA)" "select groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject from sysleftmenu where groupid in (select groupid from sysleftmenu where windowobject like 'w_fa%') order by cast(itemid as int)"
Qry "Grant utk salah satu itemid FA (contoh pola sysgroupleftmenu)" "select usergroup,itemid,s_view,s_add,s_edit,s_delete,s_cetak,s_alldata,s_koreksi,s_harga from sysgroupleftmenu where itemid in (select itemid from sysleftmenu where windowobject='w_fa_generate') order by usergroup"
Qry "Daftar usergroup (target grant ke semua)" "select distinct usergroup from sysgroupleftmenu order by usergroup"
$cn.Close()
