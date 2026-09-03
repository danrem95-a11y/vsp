$cs = "DSN=vsp;UID=dba;PWD=jakarta"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs
try{ $cn.Open() }catch{ Write-Host ("KONEKSI LOKAL GAGAL: "+$_.Exception.Message); exit 1 }
Write-Host ("Koneksi lokal OK -> "+$cn.Database)
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "0. Sanity lokal: total tbyr1 & ada faktur target?" @"
select (select count(*) from tbyr1) n_tbyr1,
       (select count(*) from gl_journal where account_id='103-001' and doc_reff='10103251100061') gl_metro,
       (select count(*) from tbyr2 where bukti_id='10103251100061') tbyr_metro
from SYS.DUMMY
"@

Qry "1. BEFORE - GL saldo vs TBYR total (3 faktur)" @"
select '10103251100061' faktur,
  (select cast(sum(debet)-sum(kredit) as numeric(18,2)) from gl_journal where posting='P' and account_id='103-001' and doc_reff='10103251100061') gl_saldo,
  (select cast(isnull(sum(nilai_bayar_idr),0) as numeric(18,2)) from tbyr2 where bukti_id='10103251100061') tbyr_total
union all select '10105250700002',
  (select cast(sum(debet)-sum(kredit) as numeric(18,2)) from gl_journal where posting='P' and account_id='103-001' and doc_reff='10105250700002'),
  (select cast(isnull(sum(nilai_bayar_idr),0) as numeric(18,2)) from tbyr2 where bukti_id='10105250700002')
"@

Qry "2. BEFORE - SAF (saldo awal 2026) 3 faktur" @"
select bukti_id, cast(saldo as numeric(18,2)) saf from SALDO_AWAL_FAKTUR where bukti_id in ('10103251100061','10105250700002')
"@

Qry "3. BEFORE - voucher backfill sudah ada? (harus 0)" @"
select count(*) hrs_nol from tbyr1 where voucher in ('200410125110261','200410125120063','200410125100303')
"@

$ar=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ar_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
$qd=$ar -replace ':arg_tgl1',"'2025-12-01'" -replace ':arg_tgl2',"'2025-12-31'"
$qj=$ar -replace ':arg_tgl1',"'2026-06-01'" -replace ':arg_tgl2',"'2026-06-30'"

Qry "4. BEFORE - Opname Des2025 SISA faktur target" @"
select ORDER_CLIENT, cast(SISA_IDR as numeric(18,2)) sisa from ($qd) x where ORDER_CLIENT in ('10103251100061','10105250700002') order by ORDER_CLIENT
"@
Qry "5. BEFORE - Opname Jun2026 TOTAL Metro(200.M096) & Bingshan(200.B587)" @"
select CUST_ID, cast(sum(SISA_IDR) as numeric(18,2)) total_jun26 from ($qj) x where CUST_ID in ('200.M096','200.B587') group by CUST_ID order by CUST_ID
"@
$cn.Close()
