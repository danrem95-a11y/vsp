$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "A. LEDGER 103-001 saldo akhir per bulan (opening + gl YTD)" @"
select bln, cast(29718846127.85 + run as numeric(18,2)) ledger_saldo_akhir from (
  select mm bln, sum(net) over (order by mm) run from (
    select month(tgl) mm, sum(debet-kredit) net from gl_journal
    where posting='P' and account_id='103-001' and tgl>='2026-01-01' and tgl<'2026-07-01' group by month(tgl)
  ) a
) b order by bln
"@

Qry "B. REKON PERSEDIAAN Juni: Ledger vs Stok (cek EVAP masih nyambung)" @"
select p.acc, cast((p.opening+isnull(j.ytd,0))-isnull(s.stok,0) as numeric(18,2)) selisih
from (select accountcode acc, sum(amountdebet-amountcredit) opening from gl_balance where site_id='101' and period='2026-01-01'
        and accountcode in (select distinct persediaan from im_product_group where persediaan is not null and persediaan<>'') group by accountcode) p
 left join (select account_id acc, sum(debet-kredit) ytd from gl_journal where posting='P' and tgl>='2026-01-01' and tgl<'2026-07-01'
        and account_id in (select distinct persediaan from im_product_group where persediaan is not null and persediaan<>'') group by account_id) j on j.acc=p.acc
 left join (select gr.persediaan acc, sum(sv.nilai) stok from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
        where sv.periode='2026-07-01' group by gr.persediaan) s on s.acc=p.acc
where abs((p.opening+isnull(j.ytd,0))-isnull(s.stok,0)) > 100
order by abs((p.opening+isnull(j.ytd,0))-isnull(s.stok,0)) desc
"@

Qry "C. NR.201A masih benar? (HPP jual + saldo akhir)" @"
select cast(isnull((select hpp from tsales2 where bukti_id='10126062200169' and stok_id='NR.201A'),0) as numeric(18,2)) hpp_jual,
       cast(isnull((select nilai from sinv where stok_id='NR.201A' and periode='2026-07-01'),0) as numeric(18,2)) saldo_akhir_jun
from SYS.DUMMY
"@
$cn.Close()
