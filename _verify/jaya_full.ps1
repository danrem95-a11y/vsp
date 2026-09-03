$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "GL semua 'JAYA DIESEL' 2026 per AKUN (debit/kredit) - dimana hutangnya?" @"
select g.account_id, max(ga.AccountDes) nm,
  cast(sum(g.debet) as numeric(18,2)) debet, cast(sum(g.kredit) as numeric(18,2)) kredit,
  cast(sum(g.kredit-g.debet) as numeric(18,2)) net_kredit
from gl_journal g left join gl_acc ga on ga.AccountCode=g.account_id and ga.site_id='101'
where g.site_id='101' and g.posting='P' and upper(isnull(g.ket,'')) like '%JAYA DIESEL%'
  and g.tgl between '2026-01-01' and '2026-07-31'
group by g.account_id order by g.account_id
"@

Qry "Akun 227-003 (Biaya YMH) Juli 2026 - semua baris" @"
select cast(g.tgl as date) tgl, g.voucher, g.urut, cast(g.debet as numeric(18,2)) debet, cast(g.kredit as numeric(18,2)) kredit, left(isnull(g.ket,''),40) ket
from gl_journal g where g.site_id='101' and g.account_id='227-003' and g.tgl between '2026-07-01' and '2026-07-31' order by g.voucher
"@

Qry "Dokumen NOITEM260700029 - ada di ap_trans? vendor & akun hutangnya" @"
select order_client, vendor_id, cast(tgl as date) tgl from ap_trans where order_client='NOITEM260700029'
"@
$cn.Close()
