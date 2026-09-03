$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

# Penerimaan AR valas Jun: voucher receipt + apakah gl_journal.voucher = tbyr voucher?
Qry "Top valas AR receipts Jun (voucher, bukti, fcy, idr)" @"
select top 8 t1.voucher, t2.bukti_id, t2.nilai_bayar fcy, cast(t2.nilai_bayar_idr as numeric(18,2)) idr, t1.voucher_manual
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.tgl>='2026-06-01' and t1.tgl<='2026-06-30' and t1.flag_bayar in (1,2)
  and abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1
  and exists(select 1 from ar_trans a2 where a2.order_client=t2.bukti_id)
order by t2.nilai_bayar_idr desc
"@

# Untuk voucher receipt AR valas Jun: kemana GL-nya? group per account
Qry "GL lines utk voucher-voucher receipt AR valas Jun (per akun)" @"
select g.account_id, gl.AccountDes,
 cast(sum(g.debet) as numeric(20,2)) debet, cast(sum(g.kredit) as numeric(20,2)) kredit,
 cast(sum(g.debet-g.kredit) as numeric(20,2)) net
from gl_journal g left join gl_acc gl on gl.AccountCode=g.account_id and gl.site_id='101'
where g.posting='P' and g.voucher in (
  select t1.voucher from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
  where t1.tgl>='2026-06-01' and t1.tgl<='2026-06-30' and t1.flag_bayar in (1,2)
    and abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1
    and exists(select 1 from ar_trans a2 where a2.order_client=t2.bukti_id))
group by g.account_id, gl.AccountDes order by abs(sum(g.debet-g.kredit)) desc
"@
$cn.Close()
