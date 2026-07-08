$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Qry($s){$c=$cn.CreateCommand();$c.CommandTimeout=200;$c.CommandText=$s;$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
Write-Host "=== 2018 modul CO ke 102-201 (asal gap 73,8jt) - top by nilai ==="
Qry "select top 15 tgl, voucher, cast(debet as numeric(18,2)) d, cast(kredit as numeric(18,2)) k, left(ket,45) ket from gl_journal where account_id='102-201' and modul_id='CO' and year(tgl)=2018 and posting='P' order by abs(debet-kredit) desc"
Write-Host "-- total CO 2018 --"
Qry "select cast(sum(debet-kredit) as numeric(18,2)) net_co_2018, count(*) n from gl_journal where account_id='102-201' and modul_id='CO' and year(tgl)=2018 and posting='P'"
Write-Host ""
Write-Host "=== rekonsiliasi gl_balance: apakah opening tiap tahun = prior opening + jurnal tahun? (cari tahun 'lompatan' manual) ==="
Qry "select year(tgl) thn, cast(sum(debet-kredit) as numeric(18,2)) jrn_net from gl_journal where account_id='102-201' and posting='P' and year(tgl) between 2018 and 2025 group by year(tgl) order by thn"
$cn.Close()
