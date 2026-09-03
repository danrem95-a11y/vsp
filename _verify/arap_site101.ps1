$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "Cek scope: gl_journal 2026 movement per site utk 226-001 (dominasi site 101?)" @"
select site_id, cast(sum(debet-kredit) as numeric(20,2)) mov2026, count(*) n
from gl_journal where posting='P' and account_id='226-001' and tgl between '2026-01-01' and '2026-06-30'
group by site_id order by abs(sum(debet-kredit)) desc
"@

Qry "Reproduksi LEDGER site101: AR(103-001) & AP(226-001+226-006) closing per bln" @"
select 'AR 103-001' acc,
  cast((select isnull(sum(amountdebet-amountcredit),0) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='103-001')
     + (select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and site_id='101' and account_id='103-001' and tgl<='2026-04-30') as numeric(20,2)) apr,
  cast((select isnull(sum(amountdebet-amountcredit),0) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='103-001')
     + (select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and site_id='101' and account_id='103-001' and tgl<='2026-05-31') as numeric(20,2)) mei,
  cast((select isnull(sum(amountdebet-amountcredit),0) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='103-001')
     + (select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and site_id='101' and account_id='103-001' and tgl<='2026-06-30') as numeric(20,2)) jun
union all
select 'AP 226-001+006',
  cast((select isnull(sum(amountcredit-amountdebet),0) from gl_balance where site_id='101' and period='2026-01-01' and accountcode in ('226-001','226-006'))
     + (select isnull(sum(kredit-debet),0) from gl_journal where posting='P' and site_id='101' and account_id in ('226-001','226-006') and tgl<='2026-04-30') as numeric(20,2)),
  cast((select isnull(sum(amountcredit-amountdebet),0) from gl_balance where site_id='101' and period='2026-01-01' and accountcode in ('226-001','226-006'))
     + (select isnull(sum(kredit-debet),0) from gl_journal where posting='P' and site_id='101' and account_id in ('226-001','226-006') and tgl<='2026-05-31') as numeric(20,2)),
  cast((select isnull(sum(amountcredit-amountdebet),0) from gl_balance where site_id='101' and period='2026-01-01' and accountcode in ('226-001','226-006'))
     + (select isnull(sum(kredit-debet),0) from gl_journal where posting='P' and site_id='101' and account_id in ('226-001','226-006') and tgl<='2026-06-30') as numeric(20,2))
"@

Qry "Offset kandidat site101: closing per bln (104x/228x/230x + MUKA) yg bergerak" @"
select x.AccountCode acc, x.AccountDes,
  cast(x.opn+x.m3 as numeric(20,2)) mar, cast(x.opn+x.m4 as numeric(20,2)) apr,
  cast(x.opn+x.m5 as numeric(20,2)) mei, cast(x.opn+x.m6 as numeric(20,2)) jun,
  cast((x.opn+x.m6)-(x.opn+x.m3) as numeric(20,2)) delta_mar_jun
from (
  select a.AccountCode, a.AccountDes,
    isnull((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and accountcode=a.AccountCode and period='2026-01-01'),0) opn,
    isnull((select sum(debet-kredit) from gl_journal where posting='P' and site_id='101' and account_id=a.AccountCode and tgl<='2026-03-31'),0) m3,
    isnull((select sum(debet-kredit) from gl_journal where posting='P' and site_id='101' and account_id=a.AccountCode and tgl<='2026-04-30'),0) m4,
    isnull((select sum(debet-kredit) from gl_journal where posting='P' and site_id='101' and account_id=a.AccountCode and tgl<='2026-05-31'),0) m5,
    isnull((select sum(debet-kredit) from gl_journal where posting='P' and site_id='101' and account_id=a.AccountCode and tgl<='2026-06-30'),0) m6
  from gl_acc a
  where a.site_id='101' and (a.AccountCode like '104%' or a.AccountCode like '228%' or a.AccountCode like '230%' or upper(a.AccountDes) like '%MUKA%' or upper(a.AccountDes) like '%TITIP%')
) x
where abs((x.opn+x.m6)-(x.opn+x.m3))>1000000
order by abs((x.opn+x.m6)-(x.opn+x.m3)) desc
"@
$cn.Close()
