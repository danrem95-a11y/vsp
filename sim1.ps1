$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
$sim = @"
from (
  select gr.PERSEDIAAN acc, sum(s.nilai + isnull(d.delta,0)) sim
  from sinv s
  join im_produk p on p.produk_id=s.stok_id
  join IM_PRODUCT_GROUP gr on gr.KODE_GROUP=p.group_product
  left join (
    select cm.stok_id, cm.mo - isnull(co.mo,0) delta
    from (select b.stok_id, sum(abs(b.netto_hpp)) mo from tstok1 a join tstok2 b on a.bukti_id=b.bukti_id where a.tipe_trans='19' and a.tgl between '2026-04-01' and '2026-04-30' group by b.stok_id) cm
    left join (select b.stok_id, sum(abs(b.qty*isnull(sv2.hpp_avg,0))) mo from tstok1 a join tstok2 b on a.bukti_id=b.bukti_id left join sinv sv2 on sv2.stok_id=b.stok_id and sv2.periode='2026-04-01' where a.tipe_trans='19' and a.tgl between '2026-04-01' and '2026-04-30' group by b.stok_id) co on co.stok_id=cm.stok_id
  ) d on d.stok_id=s.stok_id
  where s.periode='2026-05-01'
  group by gr.PERSEDIAAN
) sv
full outer join (
  select o.acc, o.opening+isnull(m.mv,0) gl from
   (select AccountCode acc, sum(AmountDebet-AmountCredit) opening from gl_balance where Period='2026-01-01' group by AccountCode) o
   left join (select account_id acc, sum(debet-kredit) mv from gl_journal where posting='P' and tgl between '2026-01-01' and '2026-04-30' group by account_id) m on m.acc=o.acc
   where o.acc in (select distinct PERSEDIAAN from IM_PRODUCT_GROUP where isnull(PERSEDIAAN,'')<>'')
) g on g.acc=sv.acc
"@
Write-Host "=== SIMULASI (read-only) April: Inventory_simulasi vs GL - akun selisih>100 ==="
Reader ("select isnull(sv.acc,g.acc) akun, cast(isnull(sv.sim,0) as numeric(18,0)) inv_sim, cast(isnull(g.gl,0) as numeric(18,0)) gl, cast(isnull(sv.sim,0)-isnull(g.gl,0) as numeric(18,0)) selisih " + $sim + " where abs(isnull(sv.sim,0)-isnull(g.gl,0)) > 100 order by selisih")
Write-Host "`n=== TOTAL simulasi ==="
Reader ("select cast(sum(isnull(sv.sim,0)) as numeric(18,0)) tot_inv_sim, cast(sum(isnull(g.gl,0)) as numeric(18,0)) tot_gl, cast(sum(isnull(sv.sim,0))-sum(isnull(g.gl,0)) as numeric(18,0)) selisih " + $sim)
$cn.Close()
