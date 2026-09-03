$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
Qry "1. GL Juni balance? (debet - kredit harus 0)" @"
select cast(sum(debet) as numeric(18,2)) debet, cast(sum(kredit) as numeric(18,2)) kredit, cast(sum(debet-kredit) as numeric(18,2)) selisih
from gl_journal where posting='P' and tgl>='2026-06-01' and tgl<'2026-07-01'
"@
Qry "2. Modul yg ke-posting di Juni (semua langkah refresh hadir?)" @"
select modul_id, count(*) n from gl_journal where posting='P' and tgl>='2026-06-01' and tgl<'2026-07-01' group by modul_id order by modul_id
"@
$cn.Close()
