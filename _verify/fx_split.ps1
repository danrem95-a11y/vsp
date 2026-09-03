$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "226-001+006 net movement CUMULATIVE by curr_id @ eom (Cr-Dr, IDR value)" @"
select curr_id,
 cast(sum(case when tgl<='2026-03-31' then kredit-debet else 0 end) as numeric(20,2)) s_mar,
 cast(sum(case when tgl<='2026-04-30' then kredit-debet else 0 end) as numeric(20,2)) s_apr,
 cast(sum(case when tgl<='2026-05-31' then kredit-debet else 0 end) as numeric(20,2)) s_mei,
 cast(sum(case when tgl<='2026-06-30' then kredit-debet else 0 end) as numeric(20,2)) s_jun
from gl_journal where posting='P' and site_id='101' and account_id in ('226-001','226-006') and tgl>='2026-01-01' and tgl<='2026-06-30'
group by curr_id order by curr_id
"@

Qry "103-001 net movement CUMULATIVE by curr_id @ eom (Dr-Cr, IDR value)" @"
select curr_id,
 cast(sum(case when tgl<='2026-03-31' then debet-kredit else 0 end) as numeric(20,2)) s_mar,
 cast(sum(case when tgl<='2026-04-30' then debet-kredit else 0 end) as numeric(20,2)) s_apr,
 cast(sum(case when tgl<='2026-05-31' then debet-kredit else 0 end) as numeric(20,2)) s_mei,
 cast(sum(case when tgl<='2026-06-30' then debet-kredit else 0 end) as numeric(20,2)) s_jun
from gl_journal where posting='P' and site_id='101' and account_id='103-001' and tgl>='2026-01-01' and tgl<='2026-06-30'
group by curr_id order by curr_id
"@

Qry "AP valas: apakah ada posting SELISIH KURS ke 226? cek modul_id x curr_id (net & count) 2026" @"
select modul_id, curr_id, count(*) n, cast(sum(kredit-debet) as numeric(20,2)) net_idr, cast(sum(kredit_kurs-debet_kurs) as numeric(20,2)) net_valas
from gl_journal where posting='P' and site_id='101' and account_id in ('226-001','226-006') and isnull(curr_id,'IDR')<>'IDR' and tgl between '2026-01-01' and '2026-06-30'
group by modul_id, curr_id order by modul_id, curr_id
"@

Qry "AR valas: modul_id x curr_id (net & count) 2026 di 103-001" @"
select modul_id, curr_id, count(*) n, cast(sum(debet-kredit) as numeric(20,2)) net_idr, cast(sum(debet_kurs-kredit_kurs) as numeric(20,2)) net_valas
from gl_journal where posting='P' and site_id='101' and account_id='103-001' and isnull(curr_id,'IDR')<>'IDR' and tgl between '2026-01-01' and '2026-06-30'
group by modul_id, curr_id order by modul_id, curr_id
"@
$cn.Close()
