$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Scalar($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql; try{return $c.ExecuteScalar()}catch{return "ERR:"+$_.Exception.Message}}
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== kolom gl_balance ==="
$c=$cn.CreateCommand(); $c.CommandText="select * from gl_balance where 1=0"; $rd=$c.ExecuteReader()
$cols=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$cols+=$rd.GetName($i)}; $rd.Close(); Write-Host ("  "+($cols -join ", "))
Write-Host "`n=== opening 2026 gl_balance utk 102% (kalau ada kolom tahun/periode) ==="
Reader "select account_id, sum(saldo) opening from gl_balance where account_id like '102%' group by account_id order by account_id"
Write-Host "`n=== GL saldo persediaan (opening + mutasi) end-MARET vs end-APRIL, total semua 102% ==="
$openTot = Scalar "select sum(saldo) from gl_balance where account_id like '102%'"
$mvMar = Scalar "select sum(debet-kredit) from gl_journal where account_id like '102%' and posting='P' and tgl between '2026-01-01' and '2026-03-31'"
$mvApr = Scalar "select sum(debet-kredit) from gl_journal where account_id like '102%' and posting='P' and tgl between '2026-01-01' and '2026-04-30'"
Write-Host ("  opening 2026 (102%)      = " + $openTot)
Write-Host ("  + mutasi s/d 31-Mar      = " + $mvMar + "   => GL end-Mar = kalibrasi vs SINV 04/01 (24,346,237,039.99)")
Write-Host ("  + mutasi s/d 30-Apr      = " + $mvApr + "   => GL end-Apr = bandingkan vs SINV 05/01 (16,734,738,337.21)")
$cn.Close()
