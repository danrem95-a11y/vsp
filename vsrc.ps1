$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== voucher 101KM260400111 : SELURUH baris (double-entry, modul, doc_reff) ==="
Reader "select urut, account_id, cast(debet as numeric(18,0)) debet, cast(kredit as numeric(18,0)) kredit, modul_id, doc_reff, ket from gl_journal where voucher='101KM260400111' order by urut"
Write-Host "`n=== distribusi MODUL_ID di gl_journal 102-110 April (sumber voucher) ==="
Reader "select modul_id, count(*) n, cast(sum(debet) as numeric(18,0)) debet, cast(sum(kredit) as numeric(18,0)) kredit from gl_journal where account_id='102-110' and posting='P' and tgl between '2026-04-01' and '2026-04-30' group by modul_id"
Write-Host "`n=== apakah voucher 101KM (KM=?) itu dari mutasi/penyesuaian stok? pola voucher 102-110 April ==="
Reader "select substring(voucher,4,2) kode, count(*) n from gl_journal where account_id='102-110' and posting='P' and tgl between '2026-04-01' and '2026-04-30' group by substring(voucher,4,2)"
$cn.Close()
