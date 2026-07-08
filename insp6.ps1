$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Qry($s){$c=$cn.CreateCommand();$c.CommandTimeout=120;$c.CommandText=$s;$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
foreach($t in @('trace_ar1','trace_ap1')){
  Write-Host ("=== "+$t+" : rentang tgl, count, Σ komponen ===")
  Qry ("select min(tgl) mn, max(tgl) mx, count(*) n, cast(sum(saldo_awal_idr) as numeric(18,2)) s_awal, cast(sum(ttl_netto_idr) as numeric(18,2)) s_netto, cast(sum(nilai_bayar_idr) as numeric(18,2)) s_bayar, cast(sum(adj_idr) as numeric(18,2)) s_adj, cast(sum(sisa_idr) as numeric(18,2)) s_sisa from "+$t)
}
Write-Host "=== GL saldo April: AR 103-001 & AP 226-001 (untuk banding Σ sisa) ==="
Qry "select '103-001 AR' a, cast((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='103-001' and Period='2026-01-01') + (select sum(debet-kredit) from gl_journal where account_id='103-001' and tgl between '2026-01-01' and '2026-04-30' and posting='P') as numeric(18,2)) saldo"
Qry "select '226-001 AP' a, cast((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='226-001' and Period='2026-01-01') + (select sum(debet-kredit) from gl_journal where account_id='226-001' and tgl between '2026-01-01' and '2026-04-30' and posting='P') as numeric(18,2)) saldo"
$cn.Close()
