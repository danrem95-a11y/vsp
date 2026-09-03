$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "Akun Uang Muka / DP (nama)" @"
select AccountCode, AccountDes, DebetCredit from gl_acc
where site_id='101' and (upper(AccountDes) like '%MUKA%' or upper(AccountDes) like '%ADVANCE%' or upper(AccountDes) like '%D/P%' or upper(AccountDes) like '%DP %' or upper(AccountDes) like '%TITIP%')
order by AccountCode
"@

Qry "Saldo closing per bulan (opening2026 + mvmt s.d. eom): AR/AP + 104x + MUKA" @"
select x.AccountCode acc, x.AccountDes,
  cast(x.opn+x.m1 as numeric(20,2)) jan,
  cast(x.opn+x.m2 as numeric(20,2)) feb,
  cast(x.opn+x.m3 as numeric(20,2)) mar,
  cast(x.opn+x.m4 as numeric(20,2)) apr,
  cast(x.opn+x.m5 as numeric(20,2)) mei,
  cast(x.opn+x.m6 as numeric(20,2)) jun
from (
  select a.AccountCode, a.AccountDes,
    isnull((select sum(amountdebet-amountcredit) from gl_balance where accountcode=a.AccountCode and period='2026-01-01'),0) opn,
    isnull((select sum(debet-kredit) from gl_journal where posting='P' and account_id=a.AccountCode and tgl<='2026-01-31'),0) m1,
    isnull((select sum(debet-kredit) from gl_journal where posting='P' and account_id=a.AccountCode and tgl<='2026-02-28'),0) m2,
    isnull((select sum(debet-kredit) from gl_journal where posting='P' and account_id=a.AccountCode and tgl<='2026-03-31'),0) m3,
    isnull((select sum(debet-kredit) from gl_journal where posting='P' and account_id=a.AccountCode and tgl<='2026-04-30'),0) m4,
    isnull((select sum(debet-kredit) from gl_journal where posting='P' and account_id=a.AccountCode and tgl<='2026-05-31'),0) m5,
    isnull((select sum(debet-kredit) from gl_journal where posting='P' and account_id=a.AccountCode and tgl<='2026-06-30'),0) m6
  from gl_acc a
  where a.site_id='101' and (a.AccountCode in ('103-001','226-001','226-006') or a.AccountCode like '104%' or upper(a.AccountDes) like '%MUKA%')
) x
where abs(x.opn+x.m6)>1 or abs(x.opn+x.m1)>1
order by x.AccountCode
"@
$cn.Close()
