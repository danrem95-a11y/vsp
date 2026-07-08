$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Qry($s){$c=$cn.CreateCommand();$c.CommandTimeout=120;$c.CommandText=$s;$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
Write-Host "=== acc_ap / acc_ar dari gl_setup ==="
Qry "select acc_ap, acc_ar, acc_persediaan, acc_stok, site_code from gl_setup"
Write-Host "=== SALDO_AWAL_FAKTUR: periode 2026 x tipe_trans -> jumlah faktur & Σ saldo/new_saldo ==="
Qry "select periode, tipe_trans, count(*) n, cast(sum(saldo) as numeric(18,2)) sum_saldo, cast(sum(new_saldo) as numeric(18,2)) sum_new_saldo from saldo_awal_faktur where periode between '2026-04-01' and '2026-06-01' group by periode,tipe_trans order by periode,tipe_trans"
$cn.Close()
