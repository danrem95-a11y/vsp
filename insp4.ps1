$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Qry($s){$c=$cn.CreateCommand();$c.CommandTimeout=120;$c.CommandText=$s;$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
Write-Host "=== SALDO_AWAL_FAKTUR periode yang ADA (per tipe_trans) ==="
Qry "select periode, tipe_trans, count(*) n, cast(sum(saldo) as numeric(18,2)) sum_saldo from saldo_awal_faktur group by periode,tipe_trans order by periode desc,tipe_trans"
Write-Host "=== GL saldo April: 226-001 (AP) & 103-001 (AR) ==="
Qry "select account_id, cast((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode=gj.account_id and Period='2026-01-01') + sum(debet-kredit) as numeric(18,2)) saldo_apr from gl_journal gj where account_id in ('226-001','103-001') and tgl between '2026-01-01' and '2026-04-30' and posting='P' group by account_id"
$cn.Close()
