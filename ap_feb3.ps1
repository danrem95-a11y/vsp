$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. ANATOMI modul CO Feb (semua akun disentuh)" @"
select account_id, cast(sum(debet) as numeric(18,2)) debet, cast(sum(kredit) as numeric(18,2)) kredit, cast(sum(debet-kredit) as numeric(18,2)) net_db
from gl_journal where posting='P' and modul_id='CO' and tgl>='2026-02-01' and tgl<'2026-03-01'
group by account_id order by account_id
"@

Qry "2. GL 226 modul CO net per BULAN (bln by bln)" @"
select month(tgl) bln, cast(sum(kredit) as numeric(18,2)) kredit, cast(sum(debet) as numeric(18,2)) debet
from gl_journal where posting='P' and account_id in ('226-001','226-006') and modul_id='CO' and tgl>='2026-01-01' and tgl<'2026-07-01'
group by month(tgl) order by month(tgl)
"@

Qry "3. Semua modul yg posting ke 226 per BULAN (net kredit-debet)" @"
select month(tgl) bln, modul_id, cast(sum(kredit-debet) as numeric(18,2)) net
from gl_journal where posting='P' and account_id in ('226-001','226-006') and tgl>='2026-01-01' and tgl<'2026-07-01'
group by month(tgl), modul_id order by month(tgl), modul_id
"@

Qry "4. TBYR AP Feb: apakah tbyr voucher punya pasangan GL 226 debet? (sample kolom)" @"
select first t1.voucher, t1.voucher_manual, t1.tgl, t1.flag_bayar, t2.bukti_id, t2.nilai_bayar, t2.nilai_bayar_idr
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.tgl>='2026-02-01' and t1.tgl<'2026-03-01' and t1.flag_bayar in (1,2)
  and exists(select 1 from ap_trans at where at.order_client=t2.bukti_id)
order by t2.nilai_bayar_idr desc
"@
$cn.Close()
