$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandText=$sql; $rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== tabel backup SINV? ==="
Reader "select table_name from SYS.SYSTABLE where lower(table_name) like 'sinv%' order by table_name"
Write-Host "=== apa itu tipe_trans '19'? (contoh keterangan di tstok1) ==="
Reader "select top 3 tipe_trans, keterangan, bukti_id from tstok1 where tipe_trans='19' and tgl between '2026-04-01' and '2026-04-30'"
$cn.Close()
