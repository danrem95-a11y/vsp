$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=60; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
Qry "RL101202606 ringkas per kelas akun (1=aset 2=hutang 3=modal 4=pendapatan 5/6=biaya)" @"
select left(account_id,1) kelas, count(*) n, cast(sum(debet) as numeric(18,2)) debet, cast(sum(kredit) as numeric(18,2)) kredit, cast(sum(debet)-sum(kredit) as numeric(18,2)) net
from gl_journal where voucher='RL101202606' group by left(account_id,1) order by left(account_id,1)
"@
Qry "RL101202606 tgl & jumlah baris + apakah ada akun 3xx (Laba/ekuitas)?" @"
select cast(min(tgl) as date) tgl, count(*) baris,
 cast(sum(case when left(account_id,1)='3' then debet-kredit else 0 end) as numeric(18,2)) net_modal_3xx
from gl_journal where voucher='RL101202606'
"@
$cn.Close()
