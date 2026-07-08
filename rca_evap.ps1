$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
$u = "('TR.038A','TR.039A','TR.910A')"
Write-Host "=== [1] SALDO AWAL (SINV 04/01) ketiga unit ==="
Reader "select stok_id, cast(qty as numeric(18,2)) qty_mar, cast(nilai as numeric(18,0)) nilai_mar from sinv where periode='2026-04-01' and stok_id in $u order by stok_id"
Write-Host "`n=== [2] MUTASI TSTOK April per stok & tipe (masuk: 02/09/88 ; keluar: 19/12) ==="
Reader "select b.stok_id, a.tipe_trans, count(*) n, cast(sum(b.qty) as numeric(18,2)) sum_qty from tstok1 a join tstok2 b on a.bukti_id=b.bukti_id where b.stok_id in $u and a.tgl between '2026-04-01' and '2026-04-30' group by b.stok_id, a.tipe_trans order by b.stok_id, a.tipe_trans"
Write-Host "`n=== [3] MUTASI TSALES April per stok & tipe (keluar: 22/88 ; masuk retur: 32/26/36) ==="
Reader "select b.stok_id, a.tipe_trans, count(*) n, cast(sum(b.qty) as numeric(18,2)) sum_qty from tsales1 a join tsales2 b on a.bukti_id=b.bukti_id where b.stok_id in $u and a.tgl between '2026-04-01' and '2026-04-30' group by b.stok_id, a.tipe_trans order by b.stok_id, a.tipe_trans"
$cn.Close()
