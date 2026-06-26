$conn=New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=60
"=== ap_trans INDUK doc1/doc2 (ttl_kotor = sumber of_alokasi) ==="
$cmd.CommandText="SELECT order_client, ttl_kotor, ttl_netto, ttl_ppn, bayar1, kurs1 FROM ap_trans WHERE order_client IN ('10126040500001','10126040500002')"
$r=$cmd.ExecuteReader()
while($r.Read()){ "{0} ttl_kotor={1:N2} ttl_netto={2:N2} ttl_ppn={3:N2} bayar1={4} kurs1={5}" -f $r['order_client'],[decimal]$r['ttl_kotor'],[decimal]$r['ttl_netto'],[decimal]$r['ttl_ppn'],$r['bayar1'],$r['kurs1'] }
$r.Close()
"`n=== ap_trans ANAK (FR) ==="
$cmd.CommandText="SELECT order_client, order_reff, ttl_netto, freight FROM ap_trans WHERE order_reff IN ('10126040500001','10126040500002') AND bukti_id<>order_reff"
$r=$cmd.ExecuteReader()
while($r.Read()){ "{0} (reff {1}) ttl_netto={2:N2} freight={3:N2}" -f $r['order_client'],$r['order_reff'],[decimal]$r['ttl_netto'],[decimal]$r['freight'] }
$r.Close()
"`n=== simulasi ldec_total of_alokasi per induk ==="
foreach($d in '10126040500001','10126040500002'){
  $cmd.CommandText="SELECT isnull(sum(ttl_kotor),0) FROM ap_trans WHERE bukti_id='$d'"; $k=[decimal]$cmd.ExecuteScalar()
  $cmd.CommandText="SELECT isnull(sum(isnull(ttl_netto,0)+isnull(freight,0)),0) FROM ap_trans WHERE order_reff='$d' AND bukti_id<>'$d'"; $a=[decimal]$cmd.ExecuteScalar()
  $cmd.CommandText="SELECT isnull(sum(biaya_ekspedisi*qty),0) FROM tstok2 WHERE bukti_id='$d'"; $t=[decimal]$cmd.ExecuteScalar()
  "{0}: ldec_total seharusnya = {1:N2} + {2:N2} = {3:N2} | tstok2 sekarang = {4:N2}" -f $d,$k,$a,($k+$a),$t
}
$conn.Close()
