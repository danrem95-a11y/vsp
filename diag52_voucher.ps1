$ErrorActionPreference = 'Stop'
$vc = '101BTB251200032'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

function Show($q, $label) {
  $c = $conn.CreateCommand(); $c.CommandText = $q; $c.CommandTimeout = 120
  $r = $c.ExecuteReader()
  Write-Host "=== $label ===" -ForegroundColor Cyan
  while ($r.Read()) {
    $row = @()
    for ($i = 0; $i -lt $r.FieldCount; $i++) {
      $row += "$($r.GetName($i))=$($r[$i])"
    }
    Write-Host ($row -join ' | ')
  }
  $r.Close()
}

Show "SELECT BUKTI_ID, TIPE_TRANS, PERIODE, SALDO_KURS, RATE, SALDO FROM SALDO_AWAL_FAKTUR WHERE BUKTI_ID='$vc'" 'SAF rows'
Show "SELECT ORDER_CLIENT, TIPE_TRANS, TGL, ORDER_OKE, KURS, TTL_NETTO FROM AP_TRANS WHERE ORDER_CLIENT='$vc'" 'AP_TRANS rows'
Show "SELECT TP.BUKTI_ID, TP.TGL_BAYAR, TP.FLAG_ORDER, TP.NILAI_BAYAR, TP.NILAI_BAYAR_IDR FROM TBYR2_PUTIH TP WHERE TP.BUKTI_ID='$vc'" 'TBYR2_PUTIH rows'
Show "SELECT T2.BUKTI_ID, T1.TGL, T1.FLAG_BAYAR, T2.NILAI_BAYAR, T2.NILAI_BAYAR_IDR FROM TBYR1 T1 INNER JOIN TBYR2 T2 ON T2.VOUCHER=T1.VOUCHER WHERE T2.BUKTI_ID='$vc'" 'TBYR1/2 rows'
Show "SELECT voucher, account_id, debet, kredit FROM gl_journal WHERE voucher='$vc' AND account_id='226-001'" 'GL 226-001'

$conn.Close()
