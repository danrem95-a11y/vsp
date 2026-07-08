$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Scalar($s){$c=$cn.CreateCommand();$c.CommandTimeout=300;$c.CommandText=$s;return [double]$c.ExecuteScalar()}
# checklist ledger bulanan (dari workbook): AR C-col, AP H-col (utama, tanpa Check)
$chkAR=@{1=31691199996.16;2=31245559877.16;3=29221343845.16;4=19658008008.91;5=20889005099.47}
$chkAP=@{1=11057773355.95;2=16853327005.26;3=10589896599.82;4=7966923124.09;5=11672613286.33}
Write-Host ("{0,-4}{1,20}{2,20}{3,16}{4,20}{5,20}{6,16}" -f "bln","AR_GLlive","AR_chkLedger","AR_drift","AP_GLlive(226-001)","AP_chkLedger","AP_drift")
foreach($b in 1..5){
  $eom = (Get-Date -Year 2026 -Month $b -Day 1).AddMonths(1).AddDays(-1).ToString("yyyy-MM-dd")
  $ar = Scalar "SELECT ISNULL((SELECT SUM(AmountDebet-AmountCredit) FROM gl_balance WHERE AccountCode='103-001' AND YEAR(Period)=2026),0)+ISNULL((SELECT SUM(debet-kredit) FROM gl_journal WHERE account_id='103-001' AND posting='P' AND tgl BETWEEN '2026-01-01' AND '$eom'),0)"
  $ap = Scalar "SELECT ISNULL((SELECT SUM(AmountDebet-AmountCredit) FROM gl_balance WHERE AccountCode='226-001' AND YEAR(Period)=2026),0)+ISNULL((SELECT SUM(debet-kredit) FROM gl_journal WHERE account_id='226-001' AND posting='P' AND tgl BETWEEN '2026-01-01' AND '$eom'),0)"
  $apAbs=[math]::Abs($ap)
  Write-Host ("{0,-4}{1,20:N2}{2,20:N2}{3,16:N0}{4,20:N2}{5,20:N2}{6,16:N0}" -f $b,$ar,$chkAR[$b],($ar-$chkAR[$b]),$apAbs,$chkAP[$b],($apAbs-$chkAP[$b]))
}
$cn.Close()
