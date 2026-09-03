$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "1. Nama akun kunci" @"
select account_id, left(account_name,40) nama from gl_acc where account_id in ('102-001','103-001','400-002','402-001','229-021','102-020')
"@
Show "2. JURNAL LENGKAP penjualan TR.038A (order 10103260700022) - debet/kredit per akun" @"
select account_id, cast(debet as numeric(18,2)) debet, cast(kredit as numeric(18,2)) kredit, left(ket,30) ket
from gl_journal where posting='P' and (voucher='10103260700022' or doc_reff='10103260700022') order by account_id
"@
Show "3. Akun 102-001 di penjualan itu: net (Dr-Kr) - apakah net turun (milik) atau net nol (konsinyasi diakui lalu HPP)?" @"
select cast(sum(debet)-sum(kredit) as numeric(18,2)) net_102001, cast(sum(case when account_id='229-021' then kredit-debet else 0 end) as numeric(18,2)) net_229021
from gl_journal where posting='P' and (voucher='10103260700022' or doc_reff='10103260700022')
"@
Show "4. Saldo akun 229-021 (titipan/konsinyasi?) saldo awal 2026 + mutasi 2025" @"
select cast((select sum(amountcredit-amountdebet) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='229-021') as numeric(18,2)) saldo_awal_2026,
       cast((select sum(kredit-debet) from gl_journal where posting='P' and account_id='229-021' and tgl>='2025-01-01' and tgl<'2026-01-01') as numeric(18,2)) mutasi_2025
from SYS.DUMMY
"@
$P.Close()
