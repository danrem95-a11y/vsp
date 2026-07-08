$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== gl_journal 102-110 April: 10 entri terbesar ==="
Reader "select top 10 voucher, tgl, cast(debet as numeric(18,0)) debet, cast(kredit as numeric(18,0)) kredit, ket from gl_journal where account_id='102-110' and posting='P' and tgl between '2026-04-01' and '2026-04-30' order by (debet+kredit) desc"
Write-Host "`n=== total GL 102-110 April ==="
Reader "select cast(sum(debet) as numeric(18,0)) tot_debet, cast(sum(kredit) as numeric(18,0)) tot_kredit, cast(sum(debet-kredit) as numeric(18,0)) net, count(*) n from gl_journal where account_id='102-110' and posting='P' and tgl between '2026-04-01' and '2026-04-30'"
Write-Host "`n=== adakah entri >1 M (raksasa) di 102-110 April? ==="
Reader "select count(*) n_besar, cast(sum(debet+kredit) as numeric(18,0)) total_besar from gl_journal where account_id='102-110' and posting='P' and tgl between '2026-04-01' and '2026-04-30' and (debet>1000000000 or kredit>1000000000)"
$cn.Close()
