$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
$gl=@{}
$c=$cn.CreateCommand();$c.CommandText="select year(Period) y, cast(AmountDebet-AmountCredit as numeric(18,2)) v from gl_balance where AccountCode='102-201'"
$rd=$c.ExecuteReader();while($rd.Read()){$gl[[int]$rd["y"]]=[double]$rd["v"]};$rd.Close()
$sv=@{}
$c2=$cn.CreateCommand();$c2.CommandText="select year(s.periode) y, cast(sum(s.nilai) as numeric(18,2)) v from sinv s, im_produk p where s.stok_id=p.produk_id and p.group_product='MT' and month(s.periode)=1 group by year(s.periode)"
$rd2=$c2.ExecuteReader();while($rd2.Read()){$sv[[int]$rd2["y"]]=[double]$rd2["v"]};$rd2.Close()
Write-Host ("{0,-6}{1,18}{2,18}{3,18}" -f "thn","GL_opening","SINV_opening","gap(GL-SINV)")
foreach($y in 2016..2026){
  $g=0.0; if($gl.ContainsKey($y)){$g=$gl[$y]}
  $s=0.0; if($sv.ContainsKey($y)){$s=$sv[$y]}
  Write-Host ("{0,-6}{1,18:N2}{2,18:N2}{3,18:N2}" -f $y,$g,$s,($g-$s))
}
$cn.Close()
