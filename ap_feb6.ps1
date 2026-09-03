$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "A. TBYR AP Feb: split IDR vs VALAS (nilai_bayar<>nilai_bayar_idr)" @"
select
 cast(sum(case when abs(t2.nilai_bayar - t2.nilai_bayar_idr) < 1 then t2.nilai_bayar_idr else 0 end) as numeric(18,2)) idr_pay,
 cast(sum(case when abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1 then t2.nilai_bayar_idr else 0 end) as numeric(18,2)) valas_pay,
 cast(sum(case when abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1 then t2.nilai_bayar else 0 end) as numeric(18,2)) valas_orig
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.tgl>='2026-02-01' and t1.tgl<'2026-03-01' and t1.flag_bayar in (1,2)
  and exists(select 1 from ap_trans at where at.order_client=t2.bukti_id)
"@

Qry "B. ANATOMI CO Feb: bank(101/102) vs 226 vs selisih-kurs(5xx)" @"
select
 cast(sum(case when account_id like '101-%' or account_id like '102-%' then kredit-debet else 0 end) as numeric(18,2)) bank_keluar,
 cast(sum(case when account_id in ('226-001','226-006') then debet-kredit else 0 end) as numeric(18,2)) hutang_lunas,
 cast(sum(case when account_id like '5%' then debet-kredit else 0 end) as numeric(18,2)) selisih_kurs_5xx,
 cast(sum(case when account_id not like '101-%' and account_id not like '102-%' and account_id not in ('226-001','226-006') and account_id not like '5%' then debet-kredit else 0 end) as numeric(18,2)) lain
from gl_journal where posting='P' and modul_id='CO' and tgl>='2026-02-01' and tgl<'2026-03-01'
"@

Qry "C. KUMULATIF Jan1-Jun30: tbyr AP bayar vs GL 226 debet" @"
select
 cast((select sum(t2.nilai_bayar_idr) from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
        where t1.tgl>='2026-01-01' and t1.tgl<'2026-07-01' and t1.flag_bayar in (1,2)
          and exists(select 1 from ap_trans at where at.order_client=t2.bukti_id)) as numeric(18,2)) tbyr_cum,
 cast((select sum(debet) from gl_journal where posting='P' and account_id in ('226-001','226-006')
        and tgl>='2026-01-01' and tgl<'2026-07-01') as numeric(18,2)) gl226_debet_cum
from SYS.DUMMY
"@

Qry "D. VALAS payments Feb: per faktur, tbyr_idr vs adakah 226 debet sebesar itu" @"
select first 25 t2.bukti_id, cast(t2.nilai_bayar as numeric(18,2)) usd, cast(t2.nilai_bayar_idr as numeric(18,2)) idr,
  (select count(*) from gl_journal g where g.posting='P' and g.account_id in ('226-001','226-006') and g.debet>0
     and abs(g.debet - t2.nilai_bayar_idr) < 1 and g.tgl>='2026-02-01' and g.tgl<'2026-03-01') ada_gl_sama
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.tgl>='2026-02-01' and t1.tgl<'2026-03-01' and t1.flag_bayar in (1,2)
  and abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1
  and exists(select 1 from ap_trans at where at.order_client=t2.bukti_id)
order by t2.nilai_bayar_idr desc
"@
$cn.Close()
