$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out = @()
$out += "=== DIAG110: Verify fix - akhir_rpxx(consin_rp) vs GL saldo akhir vs SINV Feb ==="

$out += ""
$out += "=== Compute akhir_rpxx_new for 102-001 (TR) using consin_rp ==="

$cmd.CommandText = "SELECT SUM(ISNULL(nilai,0)) FROM sinv WHERE MONTH(periode)=1 AND YEAR(periode)=2026 AND stok_id LIKE 'TR.%'"
$r = $cmd.ExecuteReader(); $r.Read(); $awal_rp = [decimal]$r[0]; $r.Close()
$out += "awal_rp (SINV Jan TR)          = $awal_rp"

$cmd.CommandText = "SELECT SUM(t2.netto*ISNULL(t1.kurs,1)) FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t2.stok_id LIKE 'TR.%' AND t1.tipe_trans='88' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y'"
$r2 = $cmd.ExecuteReader(); $r2.Read(); $consin_rp = if($r2[0]-ne[DBNull]::Value){[decimal]$r2[0]}else{0}; $r2.Close()
$out += "consin_rp (tstok88 TR netto*kurs)   = $consin_rp"

$cmd.CommandText = "SELECT SUM(ISNULL(t2.netto,0)) FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t2.stok_id LIKE 'TR.%' AND t1.tipe_trans='09' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y'"
$r3 = $cmd.ExecuteReader(); $r3.Read(); $mutasi_in_rp = if($r3[0]-ne[DBNull]::Value){[decimal]$r3[0]}else{0}; $r3.Close()
$out += "mutasi_in_rp (tstok09 TR)          = $mutasi_in_rp"

$cmd.CommandText = "SELECT SUM(ABS(t2.netto_hpp)) FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t2.stok_id LIKE 'TR.%' AND t1.tipe_trans='19' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y'"
$r4 = $cmd.ExecuteReader(); $r4.Read(); $mutasi_out_rp = if($r4[0]-ne[DBNull]::Value){[decimal]$r4[0]}else{0}; $r4.Close()
$out += "mutasi_out_rp (tstok19 TR)         = $mutasi_out_rp"

$cmd.CommandText = "SELECT SUM(t2.qty*ISNULL(t2.hpp,0)) FROM tsales1 t1, tsales2 t2 WHERE t1.bukti_id=t2.bukti_id AND t2.stok_id LIKE 'TR.%' AND t1.tipe_trans='22' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND t1.order_oke='Y'"
$r5 = $cmd.ExecuteReader(); $r5.Read(); $jual_hpp = if($r5[0]-ne[DBNull]::Value){[decimal]$r5[0]}else{0}; $r5.Close()
$out += "jual*hpp (tsales22 TR @ current)   = $jual_hpp"

$cmd.CommandText = "SELECT SUM(t2.qty*ISNULL(t2.hpp,0)) FROM tsales1 t1, tsales2 t2 WHERE t1.bukti_id=t2.bukti_id AND t2.stok_id LIKE 'TR.%' AND t1.tipe_trans='88' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND t1.order_oke='Y'"
$r6 = $cmd.ExecuteReader(); $r6.Read(); $consout_hpp = if($r6[0]-ne[DBNull]::Value){[decimal]$r6[0]}else{0}; $r6.Close()
$out += "consout*hpp (tsales88 TR @ current) = $consout_hpp"

$akhir_new = $awal_rp + $consin_rp + $mutasi_in_rp - $jual_hpp - $consout_hpp - $mutasi_out_rp
$out += ""
$out += "akhir_rpxx_NEW = awal_rp + consin_rp + mutasi_in_rp - jual*hpp - consout*hpp - mutasi_out_rp"
$out += "akhir_rpxx_NEW = $akhir_new"

$cmd.CommandText = "SELECT SUM(ISNULL(nilai,0)) FROM sinv WHERE MONTH(periode)=2 AND YEAR(periode)=2026 AND stok_id LIKE 'TR.%'"
$r7 = $cmd.ExecuteReader(); $r7.Read(); $sinvFeb = if($r7[0]-ne[DBNull]::Value){[decimal]$r7[0]}else{0}; $r7.Close()
$out += "SINV Feb TR total (current)        = $sinvFeb"

$cmd.CommandText = "SELECT ISNULL(SUM(debet),0)-ISNULL(SUM(kredit),0) FROM gl_balance WHERE account_id='102-001' AND MONTH(periode)=1 AND YEAR(periode)=2026"
$r8 = $cmd.ExecuteReader(); $r8.Read(); $glBal = if($r8[0]-ne[DBNull]::Value){[decimal]$r8[0]}else{0}; $r8.Close()
$cmd.CommandText = "SELECT ISNULL(SUM(debet),0), ISNULL(SUM(kredit),0) FROM gl_journal WHERE account_id='102-001' AND tgl BETWEEN '2026-01-01' AND '2026-01-31'"
$r9 = $cmd.ExecuteReader(); $r9.Read(); $glDr = if($r9[0]-ne[DBNull]::Value){[decimal]$r9[0]}else{0}; $glCr = if($r9[1]-ne[DBNull]::Value){[decimal]$r9[1]}else{0}; $r9.Close()
$glAkhir = $glBal + $glDr - $glCr
$out += "GL saldo akhir Jan 102-001        = $glAkhir"

$out += ""
$out += "=== SELISIH COMPARISON ==="
$out += "OLD selisih (GL - SINV_Feb)        = $($glAkhir - $sinvFeb)"
$out += "NEW selisih (GL - akhir_rpxx_NEW)  = $($glAkhir - $akhir_new)"
$out += ""
$out += "If NEW selisih = 0, fix is CORRECT"
$out += "GL should equal akhir_rpxx_NEW after fix + re-run Closing"

$conn.Close()
$out | Out-File "c:\BTV\debug\diag110_verify_out.txt" -Encoding UTF8
Write-Host "Done"
