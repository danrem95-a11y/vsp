$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== distinct coa_id di im_produk (akun persediaan yg dipakai) ==="
Reader "select coa_id, count(*) n_produk from im_produk where isnull(coa_id,'')<>'' group by coa_id order by coa_id"
Write-Host "`n=== REKONSILIASI MARET (bersih): per coa_id  SINV(04/01) vs GL end-Mar ==="
$sql = @"
select isnull(sv.acc, g.acc) akun,
  cast(isnull(sv.sinv,0) as numeric(18,0)) sinv,
  cast(isnull(g.gl,0) as numeric(18,0)) gl,
  cast(isnull(sv.sinv,0)-isnull(g.gl,0) as numeric(18,0)) selisih
from (select p.coa_id acc, sum(s.nilai) sinv from sinv s join im_produk p on p.produk_id=s.stok_id where s.periode='2026-04-01' group by p.coa_id) sv
full outer join (
  select o.acc, o.opening+isnull(m.mv,0) gl from
   (select AccountCode acc, sum(AmountDebet-AmountCredit) opening from gl_balance where Period='2026-01-01' group by AccountCode) o
   left join (select account_id acc, sum(debet-kredit) mv from gl_journal where posting='P' and tgl between '2026-01-01' and '2026-03-31' group by account_id) m on m.acc=o.acc
   where o.acc in (select distinct coa_id from im_produk where isnull(coa_id,'')<>'')
) g on g.acc=sv.acc
order by akun
"@
Reader $sql
$cn.Close()
