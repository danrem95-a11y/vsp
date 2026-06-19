$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=vsp;uid=dba;pwd=jakarta;"
$conn.Open()
$cmd = $conn.CreateCommand()

$cmd.CommandText = "SELECT TIPE_TRANS, COUNT(*) AS JML FROM AP_TRANS GROUP BY TIPE_TRANS ORDER BY TIPE_TRANS"
$r = $cmd.ExecuteReader()
"=== TIPE_TRANS AP_TRANS ==="
while($r.Read()){ "{0},{1}" -f $r[0],$r[1] }
$r.Close()

$cmd.CommandText = "SELECT TOP 3 VENDOR_ID, ORDER_CLIENT, TIPE_TRANS FROM AP_TRANS WHERE VENDOR_ID LIKE '200.%'"
$r = $cmd.ExecuteReader()
"=== VENDOR 200.xxx in AP_TRANS ==="
while($r.Read()){ "{0},{1},{2}" -f $r[0],$r[1],$r[2] }
$r.Close()

$cmd.CommandText = "SELECT TIPE_TRANS, COUNT(*) AS JML, SUM(NEW_SALDO) AS TOTAL FROM SALDO_AWAL_FAKTUR WHERE MONTH(PERIODE)=1 AND YEAR(PERIODE)=2026 GROUP BY TIPE_TRANS"
$r = $cmd.ExecuteReader()
"=== SALDO_AWAL_FAKTUR TIPE_TRANS ==="
while($r.Read()){ "{0},{1},{2}" -f $r[0],$r[1],$r[2] }
$r.Close()

$cmd.CommandText = "SELECT TOP 5 S.BUKTI_ID, S.VENDOR_ID, S.TIPE_TRANS, S.NEW_SALDO, (SELECT COUNT(*) FROM AP_TRANS A WHERE A.ORDER_CLIENT=S.BUKTI_ID AND A.TIPE_TRANS IN ('02','05','06','12','16')) AS ADA_AP FROM SALDO_AWAL_FAKTUR S WHERE S.TIPE_TRANS=1 AND MONTH(S.PERIODE)=1 AND YEAR(S.PERIODE)=2026 ORDER BY S.BUKTI_ID"
$r = $cmd.ExecuteReader()
"=== CROSS CHECK TIPE=1 vs AP_TRANS ==="
while($r.Read()){ "{0},{1},{2},{3},{4}" -f $r[0],$r[1],$r[2],$r[3],$r[4] }
$r.Close()

$cmd.CommandText = "SELECT 'Semua' AS KAT, SUM(NEW_SALDO) AS TOTAL, COUNT(DISTINCT BUKTI_ID) AS JML FROM SALDO_AWAL_FAKTUR WHERE MONTH(PERIODE)=1 AND YEAR(PERIODE)=2026 UNION ALL SELECT 'Hanya TIPE=2', SUM(NEW_SALDO), COUNT(DISTINCT BUKTI_ID) FROM SALDO_AWAL_FAKTUR WHERE TIPE_TRANS=2 AND MONTH(PERIODE)=1 AND YEAR(PERIODE)=2026"
$r = $cmd.ExecuteReader()
"=== SELISIH TOTAL ==="
while($r.Read()){ "{0},{1},{2}" -f $r[0],$r[1],$r[2] }
$r.Close()

# Query 6: TIPE_TRANS 88 and 99 breakdown by vendor prefix
$cmd.CommandText = "SELECT TIPE_TRANS, LEFT(VENDOR_ID,3) AS PREFIX, COUNT(*) AS JML FROM AP_TRANS WHERE TIPE_TRANS IN ('88','99') GROUP BY TIPE_TRANS, LEFT(VENDOR_ID,3) ORDER BY TIPE_TRANS, JML DESC"
$r = $cmd.ExecuteReader()
"=== TIPE_TRANS 88 & 99 BY VENDOR PREFIX ==="
while($r.Read()){ "{0},{1},{2}" -f $r[0],$r[1],$r[2] }
$r.Close()

# Query 7: Sample TIPE=88 with 200.xxx vendor
$cmd.CommandText = "SELECT TOP 5 VENDOR_ID, ORDER_CLIENT, BUKTI_ID, TGL, TTL_NETTO, CURR_ID FROM AP_TRANS WHERE TIPE_TRANS='88' AND VENDOR_ID LIKE '200.%'"
$r = $cmd.ExecuteReader()
"=== SAMPLE TIPE=88 / 200.xxx VENDOR ==="
while($r.Read()){ "{0},{1},{2},{3},{4},{5}" -f $r[0],$r[1],$r[2],$r[3],$r[4],$r[5] }
$r.Close()

# Query 8: Does AP_TRANS TIPE=88 link to SALDO_AWAL_FAKTUR TIPE=1?
$cmd.CommandText = "SELECT TOP 5 A.VENDOR_ID, A.ORDER_CLIENT, A.TIPE_TRANS, (SELECT COUNT(*) FROM SALDO_AWAL_FAKTUR S WHERE S.BUKTI_ID=A.ORDER_CLIENT) AS IN_SALDO, (SELECT COUNT(*) FROM SALDO_AWAL_FAKTUR S WHERE S.BUKTI_ID=A.BUKTI_ID) AS IN_SALDO_B FROM AP_TRANS A WHERE A.TIPE_TRANS='88' AND A.VENDOR_ID LIKE '200.%' AND A.TGL BETWEEN '2026-01-01' AND '2026-01-31'"
$r = $cmd.ExecuteReader()
"=== TIPE=88 LINK TO SALDO_AWAL ==="
while($r.Read()){ "{0},{1},{2},{3},{4}" -f $r[0],$r[1],$r[2],$r[3],$r[4] }
$r.Close()

# Query 9: For SALDO_AWAL TIPE=1, does BUKTI_ID appear in AP_TRANS as BUKTI_ID?
$cmd.CommandText = "SELECT TOP 5 S.BUKTI_ID, S.VENDOR_ID, S.NEW_SALDO, (SELECT COUNT(*) FROM AP_TRANS A WHERE A.BUKTI_ID=S.BUKTI_ID) AS MATCH_BUKTI, (SELECT COUNT(*) FROM AP_TRANS A WHERE A.ORDER_CLIENT=S.BUKTI_ID) AS MATCH_OC FROM SALDO_AWAL_FAKTUR S WHERE S.TIPE_TRANS=1 AND MONTH(S.PERIODE)=1 AND YEAR(S.PERIODE)=2026 ORDER BY S.BUKTI_ID"
$r = $cmd.ExecuteReader()
"=== SALDO_AWAL TIPE=1 LINK TO AP_TRANS ==="
while($r.Read()){ "{0},{1},{2},{3},{4}" -f $r[0],$r[1],$r[2],$r[3],$r[4] }
$r.Close()

# Query 10: TIPE=99 sample
$cmd.CommandText = "SELECT TOP 5 VENDOR_ID, ORDER_CLIENT, BUKTI_ID, TGL, TTL_NETTO FROM AP_TRANS WHERE TIPE_TRANS='99'"
$r = $cmd.ExecuteReader()
"=== SAMPLE TIPE=99 ==="
while($r.Read()){ "{0},{1},{2},{3},{4}" -f $r[0],$r[1],$r[2],$r[3],$r[4] }
$r.Close()

# Query 11: 200.xxx vendor in TBYR2 -- are payments in the same TBYR tables?
$cmd.CommandText = "SELECT COUNT(*) FROM TBYR2 B2 WHERE EXISTS (SELECT 1 FROM AP_TRANS A WHERE A.ORDER_CLIENT=B2.BUKTI_ID AND A.VENDOR_ID LIKE '200.%' AND A.TIPE_TRANS='88')"
$r = $cmd.ExecuteReader()
"=== TBYR2 ROWS FOR 200.xxx/TIPE=88 ==="
while($r.Read()){ "COUNT={0}" -f $r[0] }
$r.Close()

# Run query and compare component totals vs GL ledger
$sqlFile = [System.IO.File]::ReadAllText("C:\BTV\debug\query_opname_hutang.sql")
$sqlFile = $sqlFile -replace ":arg_tgl1", "'2026-01-01'" -replace ":arg_tgl2", "'2026-01-31'"
$cmd.CommandText = $sqlFile
$r = $cmd.ExecuteReader()
$rows=0; $rows4SL=0; $rows200=0
$saldo_awal=0.0; $mutasi=0.0; $adj=0.0; $bayar=0.0; $sisa=0.0
$saldo_awal4=0.0; $mutasi4=0.0; $adj4=0.0; $bayar4=0.0; $sisa4=0.0
while($r.Read()){
    $rows++
    $id=$r["CUST_ID"].ToString()
    $sa=[double]$r["SALDO_AWAL_IDR"]; $mut=[double]$r["MUTASI_IDR"]
    $ad=[double]$r["ADJ_IDR"]; $by=[double]$r["NILAI_BAYAR_IDR"]; $si=[double]$r["SISA_IDR"]
    $saldo_awal+=$sa; $mutasi+=$mut; $adj+=$ad; $bayar+=$by; $sisa+=$si
    if($id -like "200.*"){ $rows200++ } else {
        $rows4SL++; $saldo_awal4+=$sa; $mutasi4+=$mut; $adj4+=$ad; $bayar4+=$by; $sisa4+=$si
    }
}
$r.Close()
"=== TOTAL SEMUA ({0} rows) ===" -f $rows
"SALDO_AWAL={0:N2}  MUTASI={1:N2}  ADJ={2:N2}  BAYAR={3:N2}  SISA={4:N2}" -f $saldo_awal,$mutasi,$adj,$bayar,$sisa
"=== 4SL/non-200 ONLY ({0} rows) ===" -f $rows4SL
"SALDO_AWAL={0:N2}  MUTASI={1:N2}  ADJ={2:N2}  BAYAR={3:N2}  SISA={4:N2}" -f $saldo_awal4,$mutasi4,$adj4,$bayar4,$sisa4
"=== 200.xxx ONLY ({0} rows) ===" -f $rows200
$sa200=$saldo_awal-$saldo_awal4; $m200=$mutasi-$mutasi4; $ad200=$adj-$adj4; $by200=$bayar-$bayar4; $si200=$sisa-$sisa4
"SALDO_AWAL={0:N2}  MUTASI={1:N2}  ADJ={2:N2}  BAYAR={3:N2}  SISA={4:N2}" -f $sa200,$m200,$ad200,$by200,$si200
"=== GL 226-001 REFERENCE ==="
"GL_SALDO_AWAL=14,159,923,466.61  GL_KREDIT(new_inv)=1,444,491,791.76  GL_DEBET(bayar)=4,546,641,902.42  GL_SISA=11,057,773,355.95"
$conn.Close()
