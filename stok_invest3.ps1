$csL = "DSN=vsp;UID=dba;PWD=jakarta"
$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$L = New-Object System.Data.Odbc.OdbcConnection $csL; $L.Open()
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function V($cn,$sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql; $v=$c.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return 0}; return [decimal]$v }
function Row($lbl,$sql){ $l=V $L $sql; $p=V $P $sql; Write-Host ("  {0,-38} LOKAL={1,20:N2}  PROD={2,20:N2}" -f $lbl,$l,$p) }
$s01 = "select isnull(sum(sv.nilai),0) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-001' and sv.periode="

Write-Host "== sinv 102-001 per periode: LOKAL (pra-refresh) vs PROD (pasca) =="
Row "opening 2026-01-01" ($s01+"'2026-01-01'")
Row "2026-02-01 (Jan-end)" ($s01+"'2026-02-01'")
Row "2026-05-01 (Apr-end)" ($s01+"'2026-05-01'")
Row "2026-07-01 (Jun-end)" ($s01+"'2026-07-01'")
Write-Host "== gl_balance opening 102-001 (harusnya sama) =="
Row "gl_balance opening 102-001" "select isnull(sum(amountdebet-amountcredit),0) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-001'"
Write-Host "== TR.038A (unit terbesar) detail per periode =="
Row "TR.038A nilai @2026-02-01" "select isnull(nilai,0) from sinv where stok_id='TR.038A' and periode='2026-02-01'"
Row "TR.038A qty   @2026-02-01" "select isnull(qty,0) from sinv where stok_id='TR.038A' and periode='2026-02-01'"
Row "TR.038A hpp_avg @2026-02-01" "select isnull(hpp_avg,0) from sinv where stok_id='TR.038A' and periode='2026-02-01'"
$L.Close(); $P.Close()
