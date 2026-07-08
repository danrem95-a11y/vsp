$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Scalar($s){$c=$cn.CreateCommand();$c.CommandText=$s;return [double]$c.ExecuteScalar()}
$sinvApr = Scalar "select sum(s.nilai) from sinv s,im_produk p,im_product_group g where s.periode='2026-05-01' and s.stok_id=p.produk_id and p.group_product=g.kode_group and g.persediaan='102-110'"
$sinvOpn = Scalar "select sum(s.nilai) from sinv s,im_produk p,im_product_group g where s.periode='2026-04-01' and s.stok_id=p.produk_id and p.group_product=g.kode_group and g.persediaan='102-110'"
$glOpen  = Scalar "select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-110' and Period='2026-01-01'"
$glJanApr= Scalar "select sum(debet-kredit) from gl_journal where account_id='102-110' and tgl between '2026-01-01' and '2026-04-30' and posting='P'"
$glAprMove=Scalar "select sum(debet-kredit) from gl_journal where account_id='102-110' and tgl between '2026-04-01' and '2026-04-30' and posting='P'"
$glLedger = $glOpen + $glJanApr
Write-Host ("SINV akhir Apr (=report mutasi 102-110) : {0:N2}" -f $sinvApr)
Write-Host ("GL ledger April 102-110                 : {0:N2}" -f $glLedger)
Write-Host ("  selisih mutasi vs ledger              : {0:N2}" -f ($sinvApr-$glLedger))
Write-Host ""
Write-Host ("Gerakan April: mutasi(SINV 05-01 - 04-01): {0:N2}" -f ($sinvApr-$sinvOpn))
Write-Host ("Gerakan April: GL jurnal April           : {0:N2}" -f $glAprMove)
Write-Host ("  selisih gerakan (cek 647.632)          : {0:N2}" -f (($sinvApr-$sinvOpn)-$glAprMove))
$cn.Close()
