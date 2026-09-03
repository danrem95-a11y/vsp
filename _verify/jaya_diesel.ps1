$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "Supplier JAYA DIESEL" "select vendor_id, nama from mcstsupp where upper(nama) like '%JAYA DIESEL%'"

Qry "GL bernilai ~409.800 di Juli 2026 (semua akun) - cari fakturnya" @"
select cast(g.tgl as date) tgl, g.account_id, ga.AccountDes, g.voucher, g.urut, g.posting,
  cast(g.debet as numeric(18,2)) debet, cast(g.kredit as numeric(18,2)) kredit, left(isnull(g.ket,''),34) ket
from gl_journal g left join gl_acc ga on ga.AccountCode=g.account_id and ga.site_id='101'
where g.site_id='101' and g.tgl between '2026-07-01' and '2026-07-31'
  and (abs(g.kredit-409798.80)<2 or abs(g.debet-409798.80)<2 or abs(g.kredit-409800)<2 or abs(g.debet-409800)<2)
order by g.voucher, g.urut
"@
$cn.Close()
