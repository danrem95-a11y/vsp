$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function T($label,$s){ $c=$cn.CreateCommand();$c.CommandTimeout=600;$c.CommandText=$s
  $sw=[Diagnostics.Stopwatch]::StartNew(); try{$v=$c.ExecuteScalar()}catch{$v="ERR:"+$_.Exception.Message}; $sw.Stop()
  Write-Host ("  {0,-40} {1,8} ms   -> {2}" -f $label,$sw.ElapsedMilliseconds,$v) }

# 1) subquery histori EVAP (dipakai NOT IN) - scan semua sebelum April
T "histori '88' TGL<Apr (EVAP set)" "select count(*) from TSALES1 A,TSALES2 B where A.BUKTI_ID=B.BUKTI_ID and A.TIPE_TRANS='88' and A.TGL < '2026-04-01'"
# 2) satu subquery periode berjalan (JUAL '22') TANPA NOT IN
T "JUAL '22' April (tanpa NOT IN)" "select count(*) from TSALES1 A,TSALES2 B where A.BUKTI_ID=B.BUKTI_ID and A.TIPE_TRANS='22' and A.TGL between '2026-04-01' and '2026-04-30' and A.ORDER_OKE='Y'"
# 3) JUAL '22' April DENGAN NOT IN konkatenasi (seperti di report)
T "JUAL '22' April + NOT IN konkatenasi" "select count(*) from TSALES1 A,TSALES2 B where A.BUKTI_ID=B.BUKTI_ID and A.TIPE_TRANS='22' and A.TGL between '2026-04-01' and '2026-04-30' and A.ORDER_OKE='Y' and B.STOK_ID+ISNULL(B.EVAP,'') NOT IN (select B.STOK_ID+ISNULL(B.EVAP,'') from TSALES1 A,TSALES2 B where A.BUKTI_ID=B.BUKTI_ID and A.TIPE_TRANS='88' and A.TGL < '2026-04-01')"
# 4) jumlah produk stok_item='Y'
T "produk stok_item='Y'" "select count(*) from IM_PRODUK where STOK_ITEM='Y'"
$cn.Close()
