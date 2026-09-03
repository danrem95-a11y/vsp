$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "A. VALAS Feb: tbyr yg ADA vs TIDAK ADA pasangan 226-debet sama persis" @"
select
 cast(sum(case when (select count(*) from gl_journal g where g.posting='P' and g.account_id in ('226-001','226-006') and g.debet>0
        and abs(g.debet - t2.nilai_bayar_idr) < 1 and g.tgl>='2026-02-01' and g.tgl<'2026-03-01')>0
      then t2.nilai_bayar_idr else 0 end) as numeric(18,2)) tbyr_match_gl,
 cast(sum(case when (select count(*) from gl_journal g where g.posting='P' and g.account_id in ('226-001','226-006') and g.debet>0
        and abs(g.debet - t2.nilai_bayar_idr) < 1 and g.tgl>='2026-02-01' and g.tgl<'2026-03-01')>0
      then 0 else t2.nilai_bayar_idr end) as numeric(18,2)) tbyr_NO_match
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.tgl>='2026-02-01' and t1.tgl<'2026-03-01' and t1.flag_bayar in (1,2)
  and abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1
  and exists(select 1 from ap_trans at where at.order_client=t2.bukti_id)
"@

Qry "B. Daftar VALAS Feb yg tbyr_idr TANPA pasangan 226 (vendor & faktur)" @"
select top 30 t2.bukti_id, left(isnull(s.nama,''),20) vendor, cast(t2.nilai_bayar as numeric(18,2)) usd, cast(t2.nilai_bayar_idr as numeric(18,2)) idr, t1.voucher_manual
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
 left join ap_trans at on at.order_client=t2.bukti_id
 left join mcstsupp s on s.vendor_id=at.vendor_id
where t1.tgl>='2026-02-01' and t1.tgl<'2026-03-01' and t1.flag_bayar in (1,2)
  and abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1
  and exists(select 1 from ap_trans a2 where a2.order_client=t2.bukti_id)
  and (select count(*) from gl_journal g where g.posting='P' and g.account_id in ('226-001','226-006') and g.debet>0
        and abs(g.debet - t2.nilai_bayar_idr) < 1 and g.tgl>='2026-02-01' and g.tgl<'2026-03-01')=0
order by t2.nilai_bayar_idr desc
"@

Qry "C. Untuk faktur valas NO-match teratas: 226 debet aktual per faktur (via ket/reff)" @"
select top 10 t2.bukti_id, cast(t2.nilai_bayar_idr as numeric(18,2)) tbyr_idr,
  cast((select isnull(sum(g.debet-g.kredit),0) from gl_journal g where g.posting='P' and g.account_id in ('226-001','226-006')
        and g.voucher=t2.bukti_id) as numeric(18,2)) gl226_by_bukti
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.tgl>='2026-02-01' and t1.tgl<'2026-03-01' and t1.flag_bayar in (1,2)
  and abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1
  and exists(select 1 from ap_trans a2 where a2.order_client=t2.bukti_id)
order by t2.nilai_bayar_idr desc
"@
$cn.Close()
