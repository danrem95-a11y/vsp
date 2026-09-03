$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
Qry "Net debet-kredit per MODUL Juni (yg <>0 = tak seimbang / terpotong)" @"
select modul_id, count(*) n, cast(sum(debet)-sum(kredit) as numeric(18,2)) net
from gl_journal where posting='P' and tgl>='2026-06-01' and tgl<'2026-07-01'
group by modul_id order by abs(sum(debet)-sum(kredit)) desc
"@
Qry "Voucher paling tak seimbang Juni (top 15)" @"
select top 15 voucher, modul_id, cast(sum(debet)-sum(kredit) as numeric(18,2)) net
from gl_journal where posting='P' and tgl>='2026-06-01' and tgl<'2026-07-01'
group by voucher, modul_id having abs(sum(debet)-sum(kredit))>0.01
order by abs(sum(debet)-sum(kredit)) desc
"@
$cn.Close()
