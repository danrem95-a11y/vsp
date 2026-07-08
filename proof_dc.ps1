$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
$u="('TR.038A','TR.039A','TR.910A')"
Write-Host "=== JUAL.QTY (semua '22', EVAP-filter dikomentari) per unit ==="
Reader @"
select A.STOK_ID, sum(A.QTY) JUAL_QTY from (
 SELECT B.STOK_ID,B.QTY,B.STOK_ID+ISNULL(B.EVAP,'') AS KEY1 FROM TSALES1 A,TSALES2 B
 WHERE A.BUKTI_ID=B.BUKTI_ID AND A.TIPE_TRANS='22' AND A.TGL BETWEEN '2026-04-01' AND '2026-04-30' AND ISNULL(B.qty,0)<>0 AND A.ORDER_OKE='Y'
 AND B.STOK_ID+ISNULL(B.EVAP,'') NOT IN (SELECT B.STOK_ID+ISNULL(B.EVAP,'') FROM TSALES1 A,TSALES2 B WHERE A.BUKTI_ID=B.BUKTI_ID AND A.TIPE_TRANS='88' AND A.TGL<'2026-04-01')
 )A where A.STOK_ID in $u group by A.STOK_ID order by A.STOK_ID
"@
Write-Host "`n=== JUAL_BY_EVAP.QTY ('22' AND EVAP<>'') per unit ==="
Reader @"
select A.STOK_ID, sum(A.QTY) JUAL_BY_EVAP_QTY from (
 SELECT B.STOK_ID,B.QTY FROM TSALES1 A,TSALES2 B
 WHERE A.BUKTI_ID=B.BUKTI_ID AND A.TIPE_TRANS='22' AND ISNULL(B.EVAP,'')<>'' AND ISNULL(B.QTY,0)<>0 AND A.TGL BETWEEN '2026-04-01' AND '2026-04-30'
 )A where A.STOK_ID in $u group by A.STOK_ID order by A.STOK_ID
"@
Write-Host "`n=== CONSIN_BY_EVAP.QTY (utk cek apakah 0) ==="
Reader "select b.stok_id, sum(b.qty) consin_evap_raw from tstok1 a join tstok2 b on a.bukti_id=b.bukti_id where a.tipe_trans='88' and isnull(b.coa_id,'')<>'' and a.tgl between '2026-04-01' and '2026-04-30' and b.stok_id in $u group by b.stok_id"
$cn.Close()
