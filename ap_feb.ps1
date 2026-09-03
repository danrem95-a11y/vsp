$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. GL 226-001/006 FEB per MODUL (kredit=hutang naik, debet=bayar)" @"
select modul_id, count(*) n, cast(sum(kredit) as numeric(18,2)) kredit, cast(sum(debet) as numeric(18,2)) debet, cast(sum(kredit-debet) as numeric(18,2)) net
from gl_journal where posting='P' and account_id in ('226-001','226-006') and tgl>='2026-02-01' and tgl<'2026-03-01'
group by modul_id order by abs(sum(kredit-debet)) desc
"@

Qry "2. GL 226 FEB (net>1jt) yg voucher-nya TIDAK ada di AP_TRANS (orphan sub-ledger)" @"
select gj.voucher, gj.modul_id, cast(sum(gj.kredit-gj.debet) as numeric(18,2)) net, left(max(gj.ket),45) ket
from gl_journal gj
where gj.posting='P' and gj.account_id in ('226-001','226-006') and gj.tgl>='2026-02-01' and gj.tgl<'2026-03-01'
  and not exists(select 1 from ap_trans at where at.order_client=gj.voucher)
group by gj.voucher, gj.modul_id
having abs(sum(gj.kredit-gj.debet))>1000000
order by sum(gj.kredit-gj.debet) desc
"@

Qry "3. Ringkas: total 226 Feb tanpa AP_TRANS vs dengan AP_TRANS" @"
select
  cast(sum(case when exists(select 1 from ap_trans at where at.order_client=gj.voucher) then gj.kredit-gj.debet else 0 end) as numeric(18,2)) net_ada_aptrans,
  cast(sum(case when not exists(select 1 from ap_trans at where at.order_client=gj.voucher) then gj.kredit-gj.debet else 0 end) as numeric(18,2)) net_tanpa_aptrans
from gl_journal gj where gj.posting='P' and gj.account_id in ('226-001','226-006') and gj.tgl>='2026-02-01' and gj.tgl<'2026-03-01'
"@
$cn.Close()
