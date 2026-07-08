$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Scalar($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql; try{return $c.ExecuteScalar()}catch{return "ERR:"+$_.Exception.Message}}
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== nilai Period di gl_balance (penanda opening) utk 102% ==="
Reader "select distinct Period from gl_balance where AccountCode like '102%' order by Period"
Write-Host "`n=== opening 2026 semua akun 102% (AmountDebet-AmountCredit) ==="
$open = Scalar "select sum(AmountDebet - AmountCredit) from gl_balance where AccountCode like '102%'"
Write-Host ("  opening total 102% = " + $open)
Write-Host "`n=== GL balance persediaan (opening + mutasi posting='P') ==="
$mMar = Scalar "select sum(debet-kredit) from gl_journal where account_id like '102%' and posting='P' and tgl <= '2026-03-31'"
$mApr = Scalar "select sum(debet-kredit) from gl_journal where account_id like '102%' and posting='P' and tgl <= '2026-04-30'"
Write-Host ("  GL end-Mar (102%) = opening + mutasi<=31Mar")
Write-Host ("     mutasi<=31Mar   = " + $mMar)
Write-Host ("  GL end-Apr (102%) :")
Write-Host ("     mutasi<=30Apr   = " + $mApr)
Write-Host ""
Write-Host ("  >> SINV 04/01 (akhir Mar) = 24,346,237,040   |  SINV 05/01 (akhir Apr) = 16,003,284,257")
$cn.Close()
