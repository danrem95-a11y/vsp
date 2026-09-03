$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "103-001 CUMULATIVE net by flag_dp @ eom (Dr-Cr)" @"
select isnull(flag_dp,'?') flag_dp,
 cast(sum(case when tgl<='2026-03-31' then debet-kredit else 0 end) as numeric(20,2)) s_mar,
 cast(sum(case when tgl<='2026-04-30' then debet-kredit else 0 end) as numeric(20,2)) s_apr,
 cast(sum(case when tgl<='2026-05-31' then debet-kredit else 0 end) as numeric(20,2)) s_mei,
 cast(sum(case when tgl<='2026-06-30' then debet-kredit else 0 end) as numeric(20,2)) s_jun
from gl_journal where posting='P' and site_id='101' and account_id='103-001' and tgl>='2026-01-01' and tgl<='2026-06-30'
group by isnull(flag_dp,'?') order by flag_dp
"@

Qry "226-001+006 CUMULATIVE net by flag_dp @ eom (Cr-Dr)" @"
select isnull(flag_dp,'?') flag_dp,
 cast(sum(case when tgl<='2026-03-31' then kredit-debet else 0 end) as numeric(20,2)) s_mar,
 cast(sum(case when tgl<='2026-04-30' then kredit-debet else 0 end) as numeric(20,2)) s_apr,
 cast(sum(case when tgl<='2026-05-31' then kredit-debet else 0 end) as numeric(20,2)) s_mei,
 cast(sum(case when tgl<='2026-06-30' then kredit-debet else 0 end) as numeric(20,2)) s_jun
from gl_journal where posting='P' and site_id='101' and account_id in ('226-001','226-006') and tgl>='2026-01-01' and tgl<='2026-06-30'
group by isnull(flag_dp,'?') order by flag_dp
"@

Qry "AR dtype-06 detail (muncul Apr): modul/cust/dp/ket" @"
select substring(voucher,4,2) dt, modul_id, isnull(flag_dp,'?') dp, curr_id, count(*) n, min(cust_id) cust1,
 cast(sum(debet-kredit) as numeric(20,2)) net, max(ket) ket_sample
from gl_journal where posting='P' and site_id='101' and account_id='103-001' and substring(voucher,4,2)='06' and tgl between '2026-01-01' and '2026-06-30'
group by substring(voucher,4,2), modul_id, isnull(flag_dp,'?'), curr_id
"@

Qry "AP dtype-51 detail (akselerasi): modul/cust/dp/ket" @"
select substring(voucher,4,2) dt, modul_id, isnull(flag_dp,'?') dp, curr_id, count(*) n, min(cust_id) cust1,
 cast(sum(kredit-debet) as numeric(20,2)) net, max(ket) ket_sample
from gl_journal where posting='P' and site_id='101' and account_id in ('226-001','226-006') and substring(voucher,4,2)='51' and tgl between '2026-01-01' and '2026-06-30'
group by substring(voucher,4,2), modul_id, isnull(flag_dp,'?'), curr_id
"@
$cn.Close()
