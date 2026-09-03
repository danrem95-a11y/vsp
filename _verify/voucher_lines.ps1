$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=localhost;port=2638);ENG=vsp;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs
try{$cn.Open()}catch{Write-Host ("LOKAL OPEN ERR: "+$_.Exception.Message);exit}
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | "))}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "SEMUA baris voucher 200410126070118 (kenapa cuma urut 2 yg jadi kandidat)" @"
select g.urut, g.account_id, ga.AccountDes,
  cast(g.debet as numeric(18,2)) debet, cast(g.kredit as numeric(18,2)) kredit,
  left(isnull(g.ket,''),30) ket,
  case when g.account_id in (select asset_account from FA_CATEGORY where site_id='101') and g.debet>0
       then '<-- AKUN AKTIVA (kandidat)' else '' end tanda
from gl_journal g left join gl_acc ga on ga.AccountCode=g.account_id and ga.site_id='101'
where g.voucher='200410126070118' order by g.urut
"@

Qry "Semua debit ke akun aktiva JULI (harusnya cuma 1)" @"
select cast(g.tgl as date) tgl, g.account_id, g.voucher, g.urut, cast(g.debet as numeric(18,2)) debet
from gl_journal g
where g.site_id='101' and g.debet>0
  and g.account_id in (select asset_account from FA_CATEGORY where site_id='101')
  and cast(g.tgl as date) between '2026-07-01' and '2026-07-31'
order by g.tgl, g.urut
"@
$cn.Close()
