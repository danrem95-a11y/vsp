$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== REKON per akun persediaan: LEDGER akhir Juni vs STOK akhir Juni (sinv 2026-07-01) ==="
$q = @"
select p.acc,
  cast(p.opening as numeric(18,2)) opening,
  cast(isnull(j.ytd,0) as numeric(18,2)) ytd_jun,
  cast(p.opening + isnull(j.ytd,0) as numeric(18,2)) gl_end,
  cast(isnull(s.stok_end,0) as numeric(18,2)) stok_end,
  cast((p.opening + isnull(j.ytd,0)) - isnull(s.stok_end,0) as numeric(18,2)) selisih
from
 (select accountcode acc, sum(amountdebet-amountcredit) opening
    from gl_balance where site_id='101' and period='2026-01-01'
      and accountcode in (select distinct persediaan from im_product_group where persediaan is not null and persediaan<>'')
    group by accountcode) p
 left join
 (select account_id acc, sum(debet-kredit) ytd
    from gl_journal where posting='P' and tgl >= '2026-01-01' and tgl < '2026-07-01'
      and account_id in (select distinct persediaan from im_product_group where persediaan is not null and persediaan<>'')
    group by account_id) j on j.acc=p.acc
 left join
 (select gr.persediaan acc, sum(sv.nilai) stok_end
    from sinv sv join im_produk pr on pr.produk_id=sv.stok_id
                 join im_product_group gr on gr.kode_group=pr.group_product
    where sv.periode='2026-07-01'
    group by gr.persediaan) s on s.acc=p.acc
order by abs((p.opening + isnull(j.ytd,0)) - isnull(s.stok_end,0)) desc
"@
Reader $q

$cn.Close()
