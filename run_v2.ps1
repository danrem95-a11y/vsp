$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== V2a: GL 102-110 April per MODUL (debet,kredit,net) posting=P ==="
Reader "select modul_id, cast(sum(debet) as numeric(18,2)) sdeb, cast(sum(kredit) as numeric(18,2)) skre, cast(sum(debet-kredit) as numeric(18,2)) snet, count(*) n from GL_JOURNAL where account_id='102-110' and tgl between '2026-04-01' and '2026-04-30' and posting='P' group by modul_id order by modul_id"

Write-Host "=== V2c: 15 baris terbesar |debet-kredit| (modul,ket) ==="
Reader "select top 15 modul_id, ket, cast(debet as numeric(18,2)) d, cast(kredit as numeric(18,2)) k from GL_JOURNAL where account_id='102-110' and tgl between '2026-04-01' and '2026-04-30' and posting='P' order by abs(debet-kredit) desc"
$cn.Close()
