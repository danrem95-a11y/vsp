$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $cmd=$cn.CreateCommand(); $cmd.CommandTimeout=240; $cmd.CommandText=$sql
  try{$rd=$cmd.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "GL 103-001 opening 2026 + saldo akhir Feb (referensi ledger)" @"
select cast((select isnull(sum(amountdebet-amountcredit),0) from gl_balance where site_id='101' and accountcode='103-001' and period='2026-01-01') as numeric(18,2)) opening_2026,
       cast((select isnull(sum(amountdebet-amountcredit),0) from gl_balance where site_id='101' and accountcode='103-001' and period='2026-01-01')
          + (select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and account_id='103-001' and tgl>='2026-01-01' and tgl<'2026-03-01') as numeric(18,2)) gl_saldo_akhir_feb
from SYS.DUMMY
"@

Qry "PER-VOUCHER: pembayaran GL(103-001 kredit) vs tbyr, s/d Feb -> cari beda ~35jt" @"
select top 25 v ref,
   cast(gl_kr as numeric(18,2)) gl_bayar, cast(tb as numeric(18,2)) tbyr_bayar,
   cast(gl_kr - tb as numeric(18,2)) selisih
from (
  select g.voucher v,
    (select isnull(sum(gj.kredit),0) from gl_journal gj where gj.account_id='103-001' and gj.posting='P'
        and gj.voucher=g.voucher and gj.tgl>='2026-01-01' and gj.tgl<'2026-03-01') gl_kr,
    (select isnull(sum(t2.nilai_bayar_idr),0) from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
        where t2.bukti_id=g.voucher and (t1.flag_vendor=1 or t1.flag_vendor is null) and t1.flag_bayar in (1,2)
        and t1.tgl>='2026-01-01' and t1.tgl<'2026-03-01') tb
  from (select distinct voucher from gl_journal where account_id='103-001' and posting='P' and kredit>0
        and tgl>='2026-01-01' and tgl<'2026-03-01') g
) x
where abs(gl_kr - tb) > 1
order by abs(gl_kr - tb) desc
"@

$cn.Close()
