$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== gl_journal 102-110 April: entri TERBESAR (cari 2,5 M korup) ==="
$q1=@"
select top 10 account_id, voucher, tgl, cast(debet as numeric(18,0)) debet, cast(kredit as numeric(18,0)) kredit, ket
from gl_journal where account_id='102-110' and posting='P' and tgl between '2026-04-01' and '2026-04-30'
order by (debet+kredit) desc
"@
Reader $q1
Write-Host "`n=== GL 102-110 April: total debet/kredit + apakah ada nilai raksasa ==="
$q2=@"
select cast(sum(debet) as numeric(18,0)) tot_debet, cast(sum(kredit) as numeric(18,0)) tot_kredit, cast(sum(debet-kredit) as numeric(18,0)) net, count(*) n
from gl_journal where account_id='102-110' and posting='P' and tgl between '2026-04-01' and '2026-04-30'
"@
Reader $q2
Write-Host "`n=== voucher '19' LC.12.0012 (bukti) — apakah ada di gl_journal 102-110? ==="
$q3=@"
select g.account_id, g.voucher, g.doc_reff, cast(g.debet as numeric(18,0)) debet, cast(g.kredit as numeric(18,0)) kredit
from gl_journal g where g.tgl between '2026-04-01' and '2026-04-30' and g.posting='P'
and (g.doc_reff in (select distinct a.order_client from tstok1 a join tstok2 b on a.bukti_id=b.bukti_id where b.stok_id='LC.12.0012' and a.tipe_trans='19' and a.tgl between '2026-04-01' and '2026-04-30')
     or g.voucher in (select distinct a.bukti_id from tstok1 a join tstok2 b on a.bukti_id=b.bukti_id where b.stok_id='LC.12.0012' and a.tipe_trans='19' and a.tgl between '2026-04-01' and '2026-04-30'))
"@
Reader $q3
$cn.Close()
