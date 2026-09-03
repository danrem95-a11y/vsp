$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== 102-001 GL Juni per MODUL (SEKARANG) ==="
Reader @"
select modul_id, cast(sum(debet) as numeric(18,2)) deb, cast(sum(kredit) as numeric(18,2)) kre,
       cast(sum(debet-kredit) as numeric(18,2)) net, count(*) n
from gl_journal where posting='P' and account_id='102-001' and tgl>='2026-06-01' and tgl<'2026-07-01'
group by modul_id order by modul_id
"@

Write-Host "`n=== AS debit consin: GL vs tstok88 netto (TR Juni) harus SAMA ==="
Reader @"
select
 (select cast(sum(debet) as numeric(18,2)) from gl_journal where posting='P' and account_id='102-001' and modul_id='AS' and debet>0 and tgl>='2026-06-01' and tgl<'2026-07-01') gl_consin_deb,
 (select cast(sum(t2.netto) as numeric(18,2)) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id join im_produk pr on pr.produk_id=t2.stok_id where pr.group_product='TR' and t1.tipe_trans='88' and t1.order_oke='Y' and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01') stok_consin_netto
"@

Write-Host "`n=== Consin YATIM tersisa (join doc_reff=order_client), TR Juni, beda>1 harus KOSONG ==="
Reader @"
select isnull(g.dr,t.oc) ref, cast(isnull(g.gl,0)-isnull(t.st,0) as numeric(18,2)) diff
from
 (select doc_reff dr, sum(debet) gl from gl_journal where posting='P' and account_id='102-001' and modul_id='AS' and debet>0 and tgl>='2026-06-01' and tgl<'2026-07-01' group by doc_reff) g
 full outer join
 (select t1.order_client oc, sum(t2.netto) st from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id join im_produk pr on pr.produk_id=t2.stok_id
    where pr.group_product='TR' and t1.tipe_trans='88' and t1.order_oke='Y' and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01' group by t1.order_client) t
 on g.dr=t.oc
where abs(isnull(g.gl,0)-isnull(t.st,0))>1
"@

Write-Host "`n=== TOTAL selisih material Juni (semua akun, absel>100) ==="
Reader @"
select p.acc, cast((p.opening+isnull(j.ytd,0))-isnull(s.stok_end,0) as numeric(18,2)) selisih
from
 (select accountcode acc, sum(amountdebet-amountcredit) opening from gl_balance where site_id='101' and period='2026-01-01'
    and accountcode in (select distinct persediaan from im_product_group where persediaan is not null and persediaan<>'') group by accountcode) p
 left join (select account_id acc, sum(debet-kredit) ytd from gl_journal where posting='P' and tgl>='2026-01-01' and tgl<'2026-07-01'
    and account_id in (select distinct persediaan from im_product_group where persediaan is not null and persediaan<>'') group by account_id) j on j.acc=p.acc
 left join (select gr.persediaan acc, sum(sv.nilai) stok_end from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
    where sv.periode='2026-07-01' group by gr.persediaan) s on s.acc=p.acc
where abs((p.opening+isnull(j.ytd,0))-isnull(s.stok_end,0)) > 100
order by abs((p.opening+isnull(j.ytd,0))-isnull(s.stok_end,0)) desc
"@

$cn.Close()
