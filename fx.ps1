$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Scalar($label,$s){$c=$cn.CreateCommand();$c.CommandTimeout=900;$c.CommandText=$s
  try{$v=$c.ExecuteScalar();Write-Host ("  "+$label+" = "+("{0:N2}" -f [double]$v));return [double]$v}catch{Write-Host ("  ERR "+$label+": "+$_.Exception.Message);return 0.0}}
function Table($label,$s){Write-Host $label;$c=$cn.CreateCommand();$c.CommandTimeout=900;$c.CommandText=$s;try{$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("   "+($l -join " | "))};$rd.Close()}catch{Write-Host("   ERR:"+$_.Exception.Message)}}

$apAnchor="EXISTS (SELECT 1 FROM gl_journal g2 WHERE g2.voucher=BID AND g2.kredit>0 AND g2.account_id IN ('226-001','226-006'))"

Write-Host "===== #1 FIX VIEW AP: bayar/adj di-anchor ke GL (target = 8,238,241,410.02) ====="
$saf=Scalar "ap_saf (anchored)" "SELECT ISNULL(SUM(CASE WHEN ISNULL(f.new_saldo,0)<>0 THEN f.new_saldo WHEN ISNULL(f.new_rate,0)<>0 THEN ISNULL(f.saldo_kurs,0)*f.new_rate ELSE ISNULL(f.saldo,0) END),0) FROM saldo_awal_faktur f WHERE f.tipe_trans IN (1,2) AND YEAR(f.periode)=2026 AND MONTH(f.periode)=1 AND EXISTS (SELECT 1 FROM gl_journal gj WHERE gj.voucher=f.bukti_id AND gj.kredit>0 AND gj.account_id IN ('226-001','226-006'))"
$inv=Scalar "ap_inv (anchored)" "SELECT ISNULL(SUM(CASE WHEN p.tipe_trans='05' THEN p.ttl_netto ELSE (CASE WHEN p.tipe_trans IN ('02','06','16') THEN p.ttl_netto WHEN p.tipe_trans='12' THEN -ABS(p.ttl_netto) ELSE 0 END)*ISNULL(p.kurs,1) END),0) FROM ap_trans p WHERE p.order_oke='Y' AND p.tipe_trans IN ('02','05','12','06','16') AND p.tgl BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM gl_journal gj WHERE gj.voucher=p.order_client AND gj.kredit>0 AND gj.account_id IN ('226-001','226-006'))"
$adj=Scalar "ap_adj (anchored)" "SELECT ISNULL(SUM(CASE WHEN tp.flag_order NOT IN (2,22) THEN ABS(tp.nilai_bayar_idr) ELSE -ABS(tp.nilai_bayar_idr) END),0) FROM tbyr2_putih tp WHERE tp.tgl_bayar BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM gl_journal gj WHERE gj.voucher=tp.bukti_id AND gj.kredit>0 AND gj.account_id IN ('226-001','226-006'))"
$byr=Scalar "ap_byr (anchored)" "SELECT ISNULL(SUM(ISNULL(t2.nilai_bayar_idr,0)),0) FROM tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher=t1.voucher WHERE t1.flag_bayar IN (1,2) AND t1.tgl BETWEEN '2026-01-01' AND '2026-04-30' AND EXISTS (SELECT 1 FROM gl_journal gj WHERE gj.voucher=t2.bukti_id AND gj.kredit>0 AND gj.account_id IN ('226-001','226-006'))"
$sub=$saf+$inv+$adj-$byr
Write-Host ("  >>> AP SUBLEDGER (fixed) = {0:N2}   (report=8,238,241,410.02  selisih={1:N2})" -f $sub,($sub-8238241410.02))

Write-Host ""
Write-Host "===== #2 FORENSIK: GL orphan (voucher tanpa pasangan subledger) per bulan+modul ====="
Table "--- AR 103-001: orphan debet YTD per bulan (no ar_trans & no SAF) ---" "SELECT month(gj.tgl) bln, gj.modul_id, count(*) n, cast(sum(gj.debet-gj.kredit) as numeric(18,2)) net_orphan FROM gl_journal gj WHERE gj.account_id='103-001' AND gj.posting='P' AND gj.tgl BETWEEN '2026-01-01' AND '2026-05-31' AND NOT EXISTS (SELECT 1 FROM ar_trans a WHERE a.order_client=gj.voucher) AND NOT EXISTS (SELECT 1 FROM saldo_awal_faktur f WHERE f.bukti_id=gj.voucher AND f.tipe_trans=1) GROUP BY month(gj.tgl), gj.modul_id HAVING abs(sum(gj.debet-gj.kredit))>1 ORDER BY bln, net_orphan desc"
Table "--- AP 226-001: orphan kredit YTD per bulan (no ap_trans & no SAF) ---" "SELECT month(gj.tgl) bln, gj.modul_id, count(*) n, cast(sum(gj.debet-gj.kredit) as numeric(18,2)) net_orphan FROM gl_journal gj WHERE gj.account_id='226-001' AND gj.posting='P' AND gj.tgl BETWEEN '2026-01-01' AND '2026-05-31' AND NOT EXISTS (SELECT 1 FROM ap_trans p WHERE p.order_client=gj.voucher) AND NOT EXISTS (SELECT 1 FROM saldo_awal_faktur f WHERE f.bukti_id=gj.voucher AND f.tipe_trans IN (1,2)) GROUP BY month(gj.tgl), gj.modul_id HAVING abs(sum(gj.debet-gj.kredit))>1 ORDER BY bln, net_orphan desc"
$cn.Close()
