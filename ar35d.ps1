$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $cmd=$cn.CreateCommand(); $cmd.CommandTimeout=240; $cmd.CommandText=$sql
  try{$rd=$cmd.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. SEMUA riwayat REFRESH (periode apa saja yg pernah di-refresh)" @"
select log_date, log_action, left(log_desc,45) periode, log_reff
from user_log where log_action like 'REFRESH%' order by log_date desc
"@

Qry "2. Faktur AR (gl 103-001 DEBET) di Feb dgn nilai 34-36jt (kandidat faktur baru/berubah)" @"
select voucher, tgl, cast(debet as numeric(18,2)) debet, modul_id, left(ket,40) ket
from gl_journal where account_id='103-001' and posting='P' and debet between 34000000 and 36000000
  and tgl>='2026-02-01' and tgl<'2026-03-01' order by tgl
"@

Qry "3. Pembayaran AR (tbyr) Feb dgn nilai 34-36jt" @"
select t1.voucher, t1.voucher_manual, t1.tgl, cast(t2.nilai_bayar_idr as numeric(18,2)) bayar, t2.bukti_id
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.tgl>='2026-02-01' and t1.tgl<'2026-03-01' and (t1.flag_vendor=1 or t1.flag_vendor is null) and t1.flag_bayar in (1,2)
  and t2.nilai_bayar_idr between 34000000 and 36000000 order by t1.tgl
"@

Qry "4. SALDO_AWAL_FAKTUR (opening AR) nilai 34-36jt (opening yg mungkin berubah)" @"
select bukti_id, vendor_id, periode, cast(isnull(new_saldo,0) as numeric(18,2)) new_saldo, cast(isnull(saldo,0) as numeric(18,2)) saldo
from saldo_awal_faktur where tipe_trans=1
  and ((isnull(new_saldo,0) between 34000000 and 36000000) or (isnull(saldo,0) between 34000000 and 36000000))
order by bukti_id
"@

$cn.Close()
