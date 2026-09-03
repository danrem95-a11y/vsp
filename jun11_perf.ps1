$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Scalar($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql; return $c.ExecuteScalar() }
function Timed($label,$sql){
  $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  $sw=[System.Diagnostics.Stopwatch]::StartNew()
  try{ $v=$c.ExecuteScalar() }catch{ Write-Host ("  "+$label+" : ERR "+$_.Exception.Message); return }
  $sw.Stop()
  Write-Host ("  {0,-42} = {1,8:N1} ms   (hasil={2})" -f $label,$sw.Elapsed.TotalMilliseconds,$v)
}

Write-Host "=== Ukuran tabel ==="
foreach($t in 'gl_journal','tsales1','tsales2','tstok1','tstok2','tbyr1','tbyr2','sinv'){
  Write-Host ("  {0,-12} = {1}" -f $t,(Scalar "select count(*) from $t"))
}

Write-Host "`n=== Index pada gl_journal (SYS.SYSINDEXES) ==="
$c=$cn.CreateCommand(); $c.CommandText="select iname, colnames from SYS.SYSINDEXES where fname='gl_journal'"
try{ $rd=$c.ExecuteReader(); while($rd.Read()){ Write-Host ("  "+$rd[0]+" -> "+$rd[1]) }; $rd.Close() }catch{ Write-Host ("  ERR "+$_.Exception.Message) }

Write-Host "`n=== Ambil 1 order Juni riil (AR/tsales tipe 22) ==="
$ord = Scalar "select top 1 order_client from tsales1 where tipe_trans='22' and tgl>='2026-06-01' and tgl<'2026-07-01' and order_oke='Y'"
$vou = Scalar "select top 1 voucher from gl_journal where tgl>='2026-06-01' and tgl<'2026-07-01'"
$vm  = Scalar "select top 1 voucher_manual from gl_journal where tgl>='2026-06-01' and tgl<'2026-07-01' and voucher_manual is not null and voucher_manual<>''"
Write-Host ("  order_client='{0}'  voucher='{1}'  voucher_manual='{2}'" -f $ord,$vou,$vm)

Write-Host "`n=== Waktu lookup gl_journal per kolom hot (yg dipakai delete f_transfer) ==="
Timed "gl_journal WHERE doc_reff"       "select count(*) from gl_journal where doc_reff='$ord'"
Timed "gl_journal WHERE voucher"        "select count(*) from gl_journal where voucher='$vou'"
Timed "gl_journal WHERE voucher_manual" "select count(*) from gl_journal where voucher_manual='$vm'"
Timed "gl_journal WHERE account_id+tgl" "select count(*) from gl_journal where account_id='102-001' and tgl>='2026-06-01' and tgl<'2026-07-01'"

Write-Host "`n=== Waktu lookup tabel transaksi lain per key ==="
Timed "tsales2 WHERE bukti_id" "select count(*) from tsales2 where bukti_id='$ord'"
Timed "tstok2  WHERE bukti_id" "select count(*) from tstok2 where bukti_id='$ord'"
Timed "tbyr2   WHERE bukti_id" "select count(*) from tbyr2 where bukti_id='$ord'"

$cn.Close()
