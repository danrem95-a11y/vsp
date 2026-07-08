$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Cols($t){ $c=$cn.GetSchema("Columns",@($null,$null,$t,$null)); $n=@(); foreach($r in ($c.Rows|Sort-Object {[int]$_["ORDINAL_POSITION"]})){ $n+=$r["COLUMN_NAME"] }; Write-Host ("  "+$t+": "+($n -join ", ")) }
function Tbl($label,$s){Write-Host $label;$c=$cn.CreateCommand();$c.CommandTimeout=300;$c.CommandText=$s;$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("   "+($l -join " | "))};$rd.Close()}
Cols "TBYR1"
Write-Host "=== sample 5 TBYR1 AR pembayaran (flag_bayar=1) April ==="
Tbl "" "SELECT TOP 5 t1.voucher, t1.voucher_manual, t1.tgl, t1.kas_id, t1.giro_id, cast((SELECT SUM(x.nilai_bayar_idr) FROM tbyr2 x WHERE x.voucher=t1.voucher) as numeric(18,2)) tot FROM tbyr1 t1 WHERE t1.flag_bayar=1 AND (t1.flag_vendor=1 OR t1.flag_vendor IS NULL) AND t1.tgl BETWEEN '2026-04-01' AND '2026-04-30' ORDER BY t1.voucher"
Write-Host "=== linkage test: apakah gl_journal CI 103-001 match by voucher / voucher_manual ? ==="
Tbl "  match by gl.voucher = tbyr1.voucher (CI, 103-001):" "SELECT count(distinct t1.voucher) tbyr_vouchers, count(distinct gj.voucher) gl_match FROM tbyr1 t1 LEFT JOIN gl_journal gj ON gj.voucher=t1.voucher AND gj.account_id='103-001' AND gj.modul_id='CI' WHERE t1.flag_bayar=1 AND (t1.flag_vendor=1 OR t1.flag_vendor IS NULL) AND t1.tgl BETWEEN '2026-04-01' AND '2026-04-30'"
Tbl "  match by gl.voucher_manual = tbyr1.voucher_manual (CI):" "SELECT count(distinct t1.voucher_manual) tbyr_vm, count(distinct gj.voucher_manual) gl_match FROM tbyr1 t1 LEFT JOIN gl_journal gj ON gj.voucher_manual=t1.voucher_manual AND gj.account_id='103-001' AND gj.modul_id='CI' WHERE t1.flag_bayar=1 AND (t1.flag_vendor=1 OR t1.flag_vendor IS NULL) AND t1.tgl BETWEEN '2026-04-01' AND '2026-04-30'"
Write-Host "=== CI journal 103-001 April: bagaimana voucher-nya (sample) ==="
Tbl "" "SELECT TOP 5 gj.voucher, gj.voucher_manual, gj.tgl, gj.kas_id, gj.giro_id, cast(gj.kredit as numeric(18,2)) kredit, left(gj.ket,30) ket FROM gl_journal gj WHERE gj.account_id='103-001' AND gj.modul_id='CI' AND gj.tgl BETWEEN '2026-04-01' AND '2026-04-30' ORDER BY gj.voucher"
$cn.Close()
