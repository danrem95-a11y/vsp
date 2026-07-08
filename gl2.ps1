$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== per akun 102-xxx: opening2026 + mutasi2026 => GL end-Mar & end-Apr (numeric) ==="
$sql = @"
select o.acc,
  cast(o.opening as numeric(18,0)) opening_2026,
  cast(o.opening + isnull(m3.mv,0) as numeric(18,0)) gl_end_mar,
  cast(o.opening + isnull(m4.mv,0) as numeric(18,0)) gl_end_apr
from (select AccountCode acc, sum(AmountDebet-AmountCredit) opening from gl_balance where AccountCode like '102%' and Period='2026-01-01' group by AccountCode) o
left join (select account_id acc, sum(debet-kredit) mv from gl_journal where account_id like '102%' and posting='P' and tgl between '2026-01-01' and '2026-03-31' group by account_id) m3 on m3.acc=o.acc
left join (select account_id acc, sum(debet-kredit) mv from gl_journal where account_id like '102%' and posting='P' and tgl between '2026-01-01' and '2026-04-30' group by account_id) m4 on m4.acc=o.acc
order by o.acc
"@
Reader $sql
Write-Host "`n=== TOTAL semua 102% end-Mar & end-Apr ==="
Reader "select cast(sum(o.opening) as numeric(18,0)) opening, cast(sum(o.opening)+ (select sum(debet-kredit) from gl_journal where account_id like '102%' and posting='P' and tgl between '2026-01-01' and '2026-03-31') as numeric(18,0)) gl_mar, cast(sum(o.opening)+ (select sum(debet-kredit) from gl_journal where account_id like '102%' and posting='P' and tgl between '2026-01-01' and '2026-04-30') as numeric(18,0)) gl_apr from (select AccountCode, sum(AmountDebet-AmountCredit) opening from gl_balance where AccountCode like '102%' and Period='2026-01-01' group by AccountCode) o"
Write-Host "  (SINV 04/01=24,346,237,040 ; 05/01=16,003,284,257)"
$cn.Close()
