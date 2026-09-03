$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
function Val($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql; try{$v=$c.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return [decimal]0}; return [decimal]$v}catch{return "ERR:"+$_.Exception.Message } }

$ap=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ap_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
$ap_open = Val "select isnull(sum(amountcredit-amountdebet),0) from gl_balance where site_id='101' and period='2026-01-01' and accountcode in ('226-001','226-006')"

# --- SIMULASI: Ledger 226 dikurangi DP-cumulative, apakah = Opname? ---
Write-Host "=== 1. SIMULASI OPSI A: Ledger 226 (setelah Dr226 DP) vs Opname ==="
Write-Host ("  {0,-4} {1,20} {2,20} {3,20} {4,16}" -f 'Bln','Opname','Ledger_skrg','Ledger_stlh_A','Gap_stlh_A')
foreach($p in @(@('Feb','2026-02-01','2026-02-28','2026-03-01'),@('Jun','2026-06-01','2026-06-30','2026-07-01'))){
  $lbl=$p[0]; $t1=$p[1]; $t2=$p[2]; $P=$p[3]
  $led = $ap_open + (Val "select isnull(sum(kredit-debet),0) from gl_journal where posting='P' and account_id in ('226-001','226-006') and tgl>='2026-01-01' and tgl<'$P'")
  $dp  = Val "select isnull(sum(t2.nilai_bayar_idr),0) from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t1.flag_bayar in (1,2) and upper(t1.voucher_manual) like '%DPB%' and t1.tgl<'$P'
              and exists(select 1 from ap_trans at where at.order_client=t2.bukti_id and at.tgl<'$P')"
  $q=$ap -replace ':arg_tgl1',"'$t1'" -replace ':arg_tgl2',"'$t2'"
  $opn = Val "select isnull(sum(SISA_IDR),0) from ($q) x"
  $led_after = $led - $dp
  Write-Host ("  {0,-4} {1,20:N2} {2,20:N2} {3,20:N2} {4,16:N2}" -f $lbl,$opn,$led,$led_after,($opn-$led_after))
}

Qry "2. SALDO akun 104-002 (Uang Muka) saat ini (opening + mutasi s/d Jun)" @"
select cast((select isnull(sum(amountdebet-amountcredit),0) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='104-002')
          + (select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and account_id='104-002' and tgl>='2026-01-01' and tgl<'2026-07-01')
       as numeric(18,2)) saldo_104_002_akhir_jun
from SYS.DUMMY
"@

Qry "3. FX CHECK - 4 DPB Feb: nilai di 104-002 (booking) vs tbyr (aplikasi) sama?" @"
select gj.account_id, gj.voucher, gj.tgl, cast(gj.debet as numeric(18,2)) db_104, cast(gj.kredit as numeric(18,2)) kr_104, left(gj.ket,45) ket
from gl_journal gj where gj.posting='P' and gj.account_id='104-002'
 and (gj.debet in (408727854,358602456,191590656,190783392) or gj.kredit in (408727854,358602456,191590656,190783392))
order by gj.tgl
"@

Qry "4. Total 104-002 utk THERMO KING (semua entri, cek cukup utk di-relieve)" @"
select cast(sum(debet) as numeric(18,2)) tot_debet_104, cast(sum(kredit) as numeric(18,2)) tot_kredit_104, count(*) n
from gl_journal where posting='P' and account_id='104-002' and upper(ket) like '%TK%'
"@

Qry "5. Modul apa saja yg f_transfer AP/PO hapus saat refresh (agar GJ manual aman)?" @"
select distinct modul_id, count(*) n from gl_journal where posting='P' and account_id in ('226-001','226-006') and tgl>='2026-01-01' and tgl<'2026-07-01' group by modul_id
"@
$cn.Close()
