$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
$sql = @"
select isnull(sv.acc,g.acc) akun,
  cast(isnull(sv.sinv,0) as numeric(18,0)) sinv,
  cast(isnull(g.gl,0) as numeric(18,0)) gl,
  cast(isnull(sv.sinv,0)-isnull(g.gl,0) as numeric(18,0)) selisih
from (
  select gr.PERSEDIAAN acc, sum(s.nilai) sinv
  from sinv s join im_produk p on p.produk_id=s.stok_id
  join IM_PRODUCT_GROUP gr on gr.KODE_GROUP=p.group_product
  where s.periode='2026-04-01' group by gr.PERSEDIAAN
) sv
full outer join (
  select o.acc, o.opening+isnull(m.mv,0) gl from
   (select AccountCode acc, sum(AmountDebet-AmountCredit) opening from gl_balance where Period='2026-01-01' group by AccountCode) o
   left join (select account_id acc, sum(debet-kredit) mv from gl_journal where posting='P' and tgl between '2026-01-01' and '2026-03-31' group by account_id) m on m.acc=o.acc
   where o.acc in (select distinct PERSEDIAAN from IM_PRODUCT_GROUP where isnull(PERSEDIAAN,'')<>'')
) g on g.acc=sv.acc
order by akun
"@
Write-Host "=== REKONSILIASI MARET per akun PERSEDIAAN: SINV(04/01) vs GL end-Mar ==="
Reader $sql
Write-Host "`n=== TOTAL ==="
Reader @"
select cast(sum(sinv) as numeric(18,0)) tot_sinv, cast(sum(gl) as numeric(18,0)) tot_gl, cast(sum(sinv)-sum(gl) as numeric(18,0)) selisih from (
select isnull(sv.acc,g.acc) akun, isnull(sv.sinv,0) sinv, isnull(g.gl,0) gl
from (select gr.PERSEDIAAN acc, sum(s.nilai) sinv from sinv s join im_produk p on p.produk_id=s.stok_id join IM_PRODUCT_GROUP gr on gr.KODE_GROUP=p.group_product where s.periode='2026-04-01' group by gr.PERSEDIAAN) sv
full outer join (select o.acc, o.opening+isnull(m.mv,0) gl from (select AccountCode acc, sum(AmountDebet-AmountCredit) opening from gl_balance where Period='2026-01-01' group by AccountCode) o left join (select account_id acc, sum(debet-kredit) mv from gl_journal where posting='P' and tgl between '2026-01-01' and '2026-03-31' group by account_id) m on m.acc=o.acc where o.acc in (select distinct PERSEDIAAN from IM_PRODUCT_GROUP where isnull(PERSEDIAAN,'')<>'')) g on g.acc=sv.acc
) x
"@
$cn.Close()
