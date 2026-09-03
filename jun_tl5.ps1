$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=250; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

# gap(item) = (nilai_awal_jun + net_tstok_netto_jun - cogs_jun + retur_jun) - nilai_akhir_jun
$recon = @"
select x.stok_id,
  cast(x.sj as numeric(18,2)) awal, cast(x.tk as numeric(18,2)) tstok, cast(x.co as numeric(18,2)) cogs, cast(x.sk as numeric(18,2)) akhir,
  cast((x.sj + x.tk - x.co) - x.sk as numeric(18,2)) gap
from (
 select pr.produk_id stok_id,
  isnull((select sum(nilai) from sinv where stok_id=pr.produk_id and periode='2026-06-01'),0) sj,
  isnull((select sum(nilai) from sinv where stok_id=pr.produk_id and periode='2026-07-01'),0) sk,
  isnull((select sum(t2.netto) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t2.stok_id=pr.produk_id and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01'),0) tk,
  isnull((select sum(case when s1.tipe_trans='22' then s2.hpp*s2.qty when s1.tipe_trans in ('32','26','36') then -s2.hpp*s2.qty else 0 end)
          from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id where s2.stok_id=pr.produk_id and s1.tgl>='2026-06-01' and s1.tgl<'2026-07-01'),0) co
 from im_produk pr join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-102'
) x
"@

Qry "1. TOTAL gap semua item TL/TSA (harus = 105.161,32)" "select cast(sum(gap) as numeric(18,2)) total_gap from ($recon) y"
Qry "2. Item penyumbang gap terbesar (top 15)" "select top 15 stok_id, awal, tstok, cogs, akhir, gap from ($recon) y where abs(gap)>1 order by abs(gap) desc"
$cn.Close()
