$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. CLEAN bayar Feb (tiap TBYR2 dihitung sekali) vs 2. JOINED (replikasi opname)" @"
select
 cast((select sum(t2.nilai_bayar_idr) from tbyr2 t2
        where t2.voucher in (select voucher from tbyr1 where tgl>='2026-02-01' and tgl<'2026-03-01' and flag_bayar in (1,2))
          and exists(select 1 from ap_trans at where at.order_client=t2.bukti_id)) as numeric(18,2)) clean_tbyr2_once,
 cast((select sum(t2.nilai_bayar_idr) from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
        where t1.tgl>='2026-02-01' and t1.tgl<'2026-03-01' and t1.flag_bayar in (1,2)
          and exists(select 1 from ap_trans at where at.order_client=t2.bukti_id)) as numeric(18,2)) joined_opname_style
from SYS.DUMMY
"@

Qry "3. Voucher TBYR1 Feb dgn >1 baris flag_bayar in (1,2) (sumber penggandaan)" @"
select t1.voucher, count(*) baris_tbyr1
from tbyr1 t1
where t1.tgl>='2026-02-01' and t1.tgl<'2026-03-01' and t1.flag_bayar in (1,2)
group by t1.voucher having count(*)>1
order by count(*) desc
"@

Qry "4. Detail baris TBYR1 utk voucher 26022004P122P (yg 3,34M)" @"
select voucher, voucher_manual, tgl, flag_bayar, cast(nilai_bayar as numeric(18,2)) nb
from tbyr1 where voucher='26022004P122P' order by flag_bayar
"@

Qry "5. Rincian TBYR2 utk voucher 26022004P122P (brp invoice dibayar)" @"
select bukti_id, cast(nilai_bayar as numeric(18,2)) nb, cast(nilai_bayar_idr as numeric(18,2)) nb_idr
from tbyr2 where voucher='26022004P122P' order by nilai_bayar_idr desc
"@
$cn.Close()
