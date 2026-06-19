Add-Type -AssemblyName System.Data

$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

$sql = @'
SELECT
    X.VOUCHER,
    (SELECT COUNT(*) FROM AP_TRANS A WHERE A.ORDER_CLIENT = X.VOUCHER) AS CNT_AP_ORDER_CLIENT,
    (SELECT COUNT(*) FROM AP_TRANS A WHERE A.BUKTI_ID = X.VOUCHER) AS CNT_AP_BUKTI_ID,
    (SELECT COUNT(*) FROM TBYR2_PUTIH T WHERE T.BUKTI_ID = X.VOUCHER) AS CNT_TBYR2_PUTIH,
    (SELECT COUNT(*) FROM TBYR2 T WHERE T.BUKTI_ID = X.VOUCHER) AS CNT_TBYR2,
    (SELECT COUNT(*) FROM SALDO_AWAL_FAKTUR S WHERE S.BUKTI_ID = X.VOUCHER) AS CNT_SAF
FROM (
    SELECT '101PK251200001' AS VOUCHER
    UNION ALL SELECT '101PK251200002'
    UNION ALL SELECT '101PK251200003'
    UNION ALL SELECT '101PK251200004'
    UNION ALL SELECT '101PK251200007'
    UNION ALL SELECT '101PK251200008'
    UNION ALL SELECT '101PK250700001'
) X
'@

try {
    $cmd = $con.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.CommandTimeout = 120
    $r = $cmd.ExecuteReader()
    while ($r.Read()) {
        Write-Output "$($r['VOUCHER'])|AP_OC=$($r['CNT_AP_ORDER_CLIENT'])|AP_BID=$($r['CNT_AP_BUKTI_ID'])|TPUTIH=$($r['CNT_TBYR2_PUTIH'])|TBYR2=$($r['CNT_TBYR2'])|SAF=$($r['CNT_SAF'])"
    }
    $r.Close()
}
finally {
    $con.Close()
}