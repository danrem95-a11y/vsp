$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "FinCatCode taxonomy (site101): prefix, count, range akun, contoh" @"
select left(FinCatCode,2) pfx, count(*) n, min(AccountCode) acc_min, max(AccountCode) acc_max, max(AccountDes) contoh
from gl_acc where site_id='101' and isnull(FinCatCode,'')<>'' group by left(FinCatCode,2) order by pfx
"@

Qry "Akun level-1 (header) per prefix kode 4/5/6/7/8 (nama grup)" @"
select AccountCode, AccountDes, FinCatCode, DebetCredit, AccType, LevelNo
from gl_acc where site_id='101' and LevelNo<=1 and (AccountCode like '4%' or AccountCode like '5%' or AccountCode like '6%' or AccountCode like '7%' or AccountCode like '8%')
order by AccountCode
"@
$cn.Close()
