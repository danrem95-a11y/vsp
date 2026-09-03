$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
function Val($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql; try{$v=$c.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return 0}; return [decimal]$v}catch{return "ERR" } }

Qry "1. GL 226 FEB per MODUL" @"
select modul_id, count(*) n, cast(sum(kredit) as numeric(18,2)) kredit, cast(sum(debet) as numeric(18,2)) debet, cast(sum(kredit-debet) as numeric(18,2)) net
from gl_journal where posting='P' and account_id in ('226-001','226-006') and tgl>='2026-02-01' and tgl<'2026-03-01'
group by modul_id
"@

Qry "2. GL 226 modul CO net per BULAN (Jan-Jun) - kapan CO mulai?" @"
select month(tgl) bln, count(*) n, cast(sum(kredit) as numeric(18,2)) kredit, cast(sum(debet) as numeric(18,2)) debet, cast(sum(kredit-debet) as numeric(18,2)) net
from gl_journal where posting='P' and account_id in ('226-001','226-006') and modul_id='CO' and tgl>='2026-01-01' and tgl<'2026-07-01'
group by month(tgl) order by month(tgl)
"@

Qry "3. Isi JURNAL voucher raksasa ...222 (semua akun)" @"
select account_id, cast(sum(debet) as numeric(18,2)) debet, cast(sum(kredit) as numeric(18,2)) kredit, modul_id, left(max(ket),50) ket
from gl_journal where posting='P' and voucher='200410126020222' group by account_id, modul_id order by account_id
"@
Qry "4. Isi JURNAL voucher raksasa ...173 (semua akun)" @"
select account_id, cast(sum(debet) as numeric(18,2)) debet, cast(sum(kredit) as numeric(18,2)) kredit, modul_id, left(max(ket),50) ket
from gl_journal where posting='P' and voucher='200410126020173' group by account_id, modul_id order by account_id
"@

Write-Host "== 5. Dekomposisi arus FEB: Ledger vs Opname =="
$led_kredit = Val "select sum(kredit) from gl_journal where posting='P' and account_id in ('226-001','226-006') and tgl>='2026-02-01' and tgl<'2026-03-01'"
$led_debet  = Val "select sum(debet)  from gl_journal where posting='P' and account_id in ('226-001','226-006') and tgl>='2026-02-01' and tgl<'2026-03-01'"
$led_co_kr  = Val "select sum(kredit) from gl_journal where posting='P' and account_id in ('226-001','226-006') and modul_id='CO' and tgl>='2026-02-01' and tgl<'2026-03-01'"
$led_co_db  = Val "select sum(debet)  from gl_journal where posting='P' and account_id in ('226-001','226-006') and modul_id='CO' and tgl>='2026-02-01' and tgl<'2026-03-01'"
$ap=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ap_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
$q=$ap -replace ':arg_tgl1',"'2026-02-01'" -replace ':arg_tgl2',"'2026-02-28'"
$opn_mut = Val "select sum(MUTASI_IDR) from ($q) x"
$opn_byr = Val "select sum(NILAI_BAYAR_IDR) from ($q) x"
$opn_adj = Val "select sum(ADJ_IDR) from ($q) x"
Write-Host ("  Ledger 226 Feb : kredit(hutang naik)={0:N2}  debet(bayar)={1:N2}  net={2:N2}" -f $led_kredit,$led_debet,($led_kredit-$led_debet))
Write-Host ("     modul CO saja: kredit={0:N2}  debet={1:N2}  net={2:N2}" -f $led_co_kr,$led_co_db,($led_co_kr-$led_co_db))
Write-Host ("  Opname Feb     : mutasi(beli)={0:N2}  bayar={1:N2}  adj={2:N2}" -f $opn_mut,$opn_byr,$opn_adj)
Write-Host ("  Selisih beli (ledger kredit - opname mutasi) = {0:N2}" -f ($led_kredit-$opn_mut))
Write-Host ("  Selisih bayar (ledger debet  - opname bayar ) = {0:N2}" -f ($led_debet-$opn_byr))
$cn.Close()
