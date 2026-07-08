$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Qry($s){$c=$cn.CreateCommand();$c.CommandTimeout=60;$c.CommandText=$s;try{$rd=$c.ExecuteReader()}catch{Write-Host("  ERR:"+$_.Exception.Message);return};while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
Write-Host "=== objek AP_TRANS/AR_TRANS/TBYR (tabel atau view) ==="
Qry "select table_name, table_type from sys.systable where table_name in ('AP_TRANS','AR_TRANS','TBYR1','TBYR2','TBYR2_PUTIH','ap_trans','ar_trans','tbyr1','tbyr2','tbyr2_putih')"
Write-Host "=== sanity: baris & rentang tgl ==="
Qry "select 'AP_TRANS' t, count(*) n, min(tgl) mn, max(tgl) mx from AP_TRANS"
Qry "select 'AR_TRANS' t, count(*) n, min(tgl) mn, max(tgl) mx from AR_TRANS"
Qry "select 'TBYR1' t, count(*) n, min(tgl) mn, max(tgl) mx from TBYR1"
Qry "select 'TBYR2_PUTIH' t, count(*) n, min(tgl_bayar) mn, max(tgl_bayar) mx from TBYR2_PUTIH"
$cn.Close()
