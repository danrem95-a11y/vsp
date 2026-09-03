$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "gl_journal columns" "select first * from gl_journal"

Qry "103-001 movement per DOC-TYPE (substr voucher 4,2) per bulan" @"
select substring(voucher,4,2) dtype, count(distinct voucher) nvoucher,
  cast(sum(case when tgl between '2026-01-01' and '2026-03-31' then debet-kredit else 0 end) as numeric(20,2)) q1_janmar,
  cast(sum(case when tgl between '2026-04-01' and '2026-04-30' then debet-kredit else 0 end) as numeric(20,2)) apr,
  cast(sum(case when tgl between '2026-05-01' and '2026-05-31' then debet-kredit else 0 end) as numeric(20,2)) mei,
  cast(sum(case when tgl between '2026-06-01' and '2026-06-30' then debet-kredit else 0 end) as numeric(20,2)) jun
from gl_journal where posting='P' and site_id='101' and account_id='103-001' and tgl between '2026-01-01' and '2026-06-30'
group by substring(voucher,4,2) order by dtype
"@

Qry "226-001+006 movement per DOC-TYPE (substr voucher 4,2) per bulan" @"
select substring(voucher,4,2) dtype, count(distinct voucher) nvoucher,
  cast(sum(case when tgl between '2026-01-01' and '2026-03-31' then kredit-debet else 0 end) as numeric(20,2)) q1_janmar,
  cast(sum(case when tgl between '2026-04-01' and '2026-04-30' then kredit-debet else 0 end) as numeric(20,2)) apr,
  cast(sum(case when tgl between '2026-05-01' and '2026-05-31' then kredit-debet else 0 end) as numeric(20,2)) mei,
  cast(sum(case when tgl between '2026-06-01' and '2026-06-30' then kredit-debet else 0 end) as numeric(20,2)) jun
from gl_journal where posting='P' and site_id='101' and account_id in ('226-001','226-006') and tgl between '2026-01-01' and '2026-06-30'
group by substring(voucher,4,2) order by dtype
"@
$cn.Close()
