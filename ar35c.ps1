$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $cmd=$cn.CreateCommand(); $cmd.CommandTimeout=240; $cmd.CommandText=$sql
  try{$rd=$cmd.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. Jejak REFRESH terakhir (user_log)" @"
select top 15 log_date, log_action, left(log_desc,50) log_desc, log_reff
from user_log where (log_action like '%REFRESH%' or log_desc like '%REFRESH%' or log_desc like '%WIPIN%' or log_reff like '%WIPIN%')
order by log_date desc
"@

Qry "2. Pembayaran AR 'yatim' (tbyr kas_id=0, TANPA gl_journal) Jan-Feb 2026 = kandidat yg dihapus/berubah" @"
select t1.voucher, t1.voucher_manual, t1.tgl, t1.kas_id,
   cast(sum(t2.nilai_bayar_idr) as numeric(18,2)) total_bayar, count(*) n
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.tgl>='2026-01-01' and t1.tgl<'2026-03-01' and (t1.flag_vendor=1 or t1.flag_vendor is null) and t1.flag_bayar in (1,2)
  and isnull(t1.kas_id,0)=0
  and not exists(select 1 from gl_journal g where g.voucher_manual=t1.voucher_manual)
group by t1.voucher, t1.voucher_manual, t1.tgl, t1.kas_id
order by t1.tgl
"@

Qry "3. Total pembayaran AR tbyr per bulan (Jan-Feb) - utk banding cepat" @"
select month(t1.tgl) bln, cast(sum(t2.nilai_bayar_idr) as numeric(18,2)) total_tbyr, count(distinct t1.voucher) n_voucher
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.tgl>='2026-01-01' and t1.tgl<'2026-03-01' and (t1.flag_vendor=1 or t1.flag_vendor is null) and t1.flag_bayar in (1,2)
group by month(t1.tgl) order by bln
"@

Qry "4. gl_journal 103-001 KREDIT (pembayaran) senilai ~35jt +/- di SEMUA 2026 (jaga-jaga)" @"
select voucher, tgl, cast(kredit as numeric(18,2)) kredit, modul_id, left(ket,35) ket
from gl_journal where account_id='103-001' and posting='P' and kredit between 34000000 and 36000000 and tgl>='2026-01-01' and tgl<'2026-07-01'
order by tgl
"@

$cn.Close()
