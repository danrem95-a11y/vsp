$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Qry($s){$c=$cn.CreateCommand();$c.CommandTimeout=300;$c.CommandText=$s;try{$rd=$c.ExecuteReader()}catch{Write-Host("  ERR:"+$_.Exception.Message);return};while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
Write-Host "=== gl_setup: acc_biaya_ekpedisi, acc_nota_*, site_code ==="
Qry "select acc_ap, acc_ar, acc_biaya_ekpedisi, acc_nota_debet_ap, acc_nota_kredit_ap, acc_nota_debet_ar, acc_nota_kredit_ar, isnull(site_code,'(null)') site_code from gl_setup"
Write-Host "=== DATA-DRIVEN: akun GL (kredit>0) yang voucher-nya = AP_TRANS.ORDER_CLIENT (2026) ==="
Qry "select gj.account_id, count(*) n, cast(sum(gj.kredit) as numeric(18,2)) sum_kredit from gl_journal gj where gj.kredit>0 and gj.posting='P' and year(gj.tgl)=2026 and exists (select 1 from ap_trans p where p.order_client=gj.voucher) group by gj.account_id having count(*)>=5 order by sum_kredit desc"
Write-Host "=== DATA-DRIVEN: akun GL (debet>0) voucher = AR_TRANS.ORDER_CLIENT (2026) ==="
Qry "select gj.account_id, count(*) n, cast(sum(gj.debet) as numeric(18,2)) sum_debet from gl_journal gj where gj.debet>0 and gj.posting='P' and year(gj.tgl)=2026 and exists (select 1 from ar_trans a where a.order_client=gj.voucher) group by gj.account_id having count(*)>=5 order by sum_debet desc"
$cn.Close()
