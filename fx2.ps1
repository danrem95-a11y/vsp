$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function S($s){$c=$cn.CreateCommand();$c.CommandTimeout=900;$c.CommandText=$s;return [double]$c.ExecuteScalar()}
function Tbl($label,$s){Write-Host $label;$c=$cn.CreateCommand();$c.CommandTimeout=900;$c.CommandText=$s;$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("   "+($l -join " | "))};$rd.Close()}
$saf_ar = 29718846058.79
$ar_glopen = S "SELECT ISNULL(SUM(AmountDebet-AmountCredit),0) FROM gl_balance WHERE AccountCode='103-001' AND YEAR(Period)=2026"
$ar_debet  = S "SELECT ISNULL(SUM(debet),0) FROM gl_journal WHERE account_id='103-001' AND posting='P' AND tgl BETWEEN '2026-01-01' AND '2026-04-30'"
$ar_kredit = S "SELECT ISNULL(SUM(kredit),0) FROM gl_journal WHERE account_id='103-001' AND posting='P' AND tgl BETWEEN '2026-01-01' AND '2026-04-30'"
$ar_deb_anch = S "SELECT ISNULL(SUM(gj.debet),0) FROM gl_journal gj WHERE gj.debet>0 AND gj.account_id='103-001' AND gj.tgl BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM ar_trans a WHERE a.order_client=gj.voucher AND a.order_oke='Y' AND a.tipe_trans IN ('22','32','33','26','36'))"
Write-Host "=== AR 103-001 (YTD Apr) ==="
Write-Host ("  gl_open={0:N2}  saf_open={1:N2}  d_open={2:N2}" -f $ar_glopen,$saf_ar,($ar_glopen-$saf_ar))
Write-Host ("  gl_debet_all={0:N2}  debet_anchored={1:N2}  d_debet={2:N2}" -f $ar_debet,$ar_deb_anch,($ar_debet-$ar_deb_anch))
Write-Host ("  gl_kredit_all={0:N2}   GL_bal={1:N2}" -f $ar_kredit,($ar_glopen+$ar_debet-$ar_kredit))
$ap_glopen = S "SELECT ISNULL(SUM(AmountDebet-AmountCredit),0) FROM gl_balance WHERE AccountCode='226-001' AND YEAR(Period)=2026"
$ap_debet  = S "SELECT ISNULL(SUM(debet),0) FROM gl_journal WHERE account_id='226-001' AND posting='P' AND tgl BETWEEN '2026-01-01' AND '2026-04-30'"
$ap_kredit = S "SELECT ISNULL(SUM(kredit),0) FROM gl_journal WHERE account_id='226-001' AND posting='P' AND tgl BETWEEN '2026-01-01' AND '2026-04-30'"
$ap_kre_anch = S "SELECT ISNULL(SUM(gj.kredit),0) FROM gl_journal gj WHERE gj.kredit>0 AND gj.account_id='226-001' AND gj.tgl BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM ap_trans p WHERE p.order_client=gj.voucher AND p.order_oke='Y')"
Write-Host "=== AP 226-001 (YTD Apr) ==="
Write-Host ("  gl_open={0:N2}" -f $ap_glopen)
Write-Host ("  gl_kredit_all={0:N2}  kredit_anchored={1:N2}  d_kredit={2:N2}" -f $ap_kredit,$ap_kre_anch,($ap_kredit-$ap_kre_anch))
Write-Host ("  gl_debet_all={0:N2}   GL_bal_net={1:N2}" -f $ap_debet,($ap_glopen+$ap_debet-$ap_kredit))
Tbl "=== AR modul GL 103-001 net YTD Apr ===" "SELECT gj.modul_id md, count(*) n, cast(sum(gj.debet) as numeric(18,2)) deb, cast(sum(gj.kredit) as numeric(18,2)) kre FROM gl_journal gj WHERE gj.account_id='103-001' AND gj.posting='P' AND gj.tgl BETWEEN '2026-01-01' AND '2026-04-30' GROUP BY gj.modul_id ORDER BY gj.modul_id"
Tbl "=== AP modul GL 226-001 net YTD Apr ===" "SELECT gj.modul_id md, count(*) n, cast(sum(gj.debet) as numeric(18,2)) deb, cast(sum(gj.kredit) as numeric(18,2)) kre FROM gl_journal gj WHERE gj.account_id='226-001' AND gj.posting='P' AND gj.tgl BETWEEN '2026-01-01' AND '2026-04-30' GROUP BY gj.modul_id ORDER BY gj.modul_id"
$cn.Close()
