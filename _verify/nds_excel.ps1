$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Val($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql; try{$v=$c.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return [decimal]0}; return [decimal]$v}catch{return "ERR:"+$_.Exception.Message} }
function N($d){ if($d -is [string]){return $d}; return ('{0:N2}' -f $d) }

$acc='102-103'
# opening 2026 GL akun ini
$open = Val "select isnull(sum(amountdebet-amountcredit),0) from gl_balance where accountcode='$acc' and period='2026-01-01'"

$months = @(
 @('Jan','2026-02-01','2026-01-31'), @('Peb','2026-03-01','2026-02-28'), @('Mar','2026-04-01','2026-03-31'),
 @('Apr','2026-05-01','2026-04-30'), @('Mei','2026-06-01','2026-05-31'), @('Jun','2026-07-01','2026-06-30'),
 @('Jul','2026-08-01','2026-07-31'), @('Agu','2026-09-01','2026-08-31'), @('Sep','2026-10-01','2026-09-30'),
 @('Okt','2026-11-01','2026-10-31'), @('Nop','2026-12-01','2026-11-30'), @('Des','2027-01-01','2026-12-31') )

Write-Host ("  NDS   | {0,18} | {1,18} | {2,10}" -f 'MUTASI STOK','LEDGER','Check')
Write-Host ("  "+("-"*64))
foreach($m in $months){
  $lbl=$m[0]; $next=$m[1]; $eom=$m[2]
  $stok = Val "select isnull(sum(sv.nilai),0) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='$acc' and sv.periode='$next'"
  $mov  = Val "select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and account_id='$acc' and tgl>='2026-01-01' and tgl<='$eom'"
  $ledger = $open + $mov
  $chk = $stok - $ledger
  Write-Host ("  {0,-5} | {1,18} | {2,18} | {3,10}" -f $lbl,(N $stok),(N $ledger),(N $chk))
}
$cn.Close()
