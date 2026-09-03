$cs = "DSN=vsp;UID=dba;PWD=jakarta"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Exec($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql; return $c.ExecuteNonQuery() }
function Scal($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql; try{$v=$c.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return 0}; return [decimal]$v}catch{return 'ERR:'+$_.Exception.Message} }
$ar=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ar_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
function OpnFaktur($t1,$t2,$oc){ $q=$ar -replace ':arg_tgl1',"'$t1'" -replace ':arg_tgl2',"'$t2'"; return Scal "select cast(isnull(sum(SISA_IDR),0) as numeric(18,2)) from ($q) x where ORDER_CLIENT='$oc'" }
function OpnCust($t1,$t2,$cust){ $q=$ar -replace ':arg_tgl1',"'$t1'" -replace ':arg_tgl2',"'$t2'"; return Scal "select cast(isnull(sum(SISA_IDR),0) as numeric(18,2)) from ($q) x where CUST_ID='$cust'" }
function SAF(){ return Scal "select cast(saldo as numeric(18,2)) from SALDO_AWAL_FAKTUR where bukti_id='10103251100061'" }
function Snap($tag){ Write-Host ("  [$tag] OpnameDes25 faktur=" + (OpnFaktur '2025-12-01' '2025-12-31' '10103251100061') + " | SAF2026=" + (SAF) + " | OpnameJun26 Metro=" + (OpnCust '2026-06-01' '2026-06-30' '200.M096')) }

Write-Host "=== BASELINE (lokal masih punya record 2025) ==="
Snap "BASELINE"

Write-Host "`n=== STEP 1: BACKUP + HAPUS 2 record Metro 2025 (simulasi lubang prod) ==="
try{ Exec "select * into #bkp1 from tbyr1 where voucher in ('25112004R117R','25122004R009R')" | Out-Null
     Exec "select * into #bkp2 from tbyr2 where voucher in ('25112004R117R','25122004R009R')" | Out-Null }catch{ Write-Host ("  backup ERR: "+$_.Exception.Message) }
$b1 = Scal "select count(*) from #bkp1"; $b2 = Scal "select count(*) from #bkp2"
Write-Host "  backup: tbyr1=$b1 tbyr2=$b2"
Exec "delete from tbyr2 where voucher in ('25112004R117R','25122004R009R')" | Out-Null
Exec "delete from tbyr1 where voucher in ('25112004R117R','25122004R009R')" | Out-Null
Exec "commit" | Out-Null
Snap "LUBANG"

Write-Host "`n=== STEP 2: BACKFILL (runbook: reinsert nilai persis) ==="
Exec "insert into tbyr1 (voucher,voucher_manual,tgl,flag_bayar,flag_vendor,vendor_id,kas_id,curr_id,kurs,site_id,kolektor_id,keterangan) values ('25112004R117R','25112004R117','2025-11-28',1,1,'200.M096',0,'IDR',1,'101','K001','BACKFILL2025 CI UNIT KE-1 P331/11/25')" | Out-Null
Exec "insert into tbyr2 (voucher,urut,bukti_id,nilai_bayar,nilai_bayar_idr,acc_bayar,flag_order) values ('25112004R117R',1,'10103251100061',200000000,200000000,'103-001',1)" | Out-Null
Exec "insert into tbyr1 (voucher,voucher_manual,tgl,flag_bayar,flag_vendor,vendor_id,kas_id,curr_id,kurs,site_id,kolektor_id,keterangan) values ('25122004R009R','25122004R009','2025-12-03',1,1,'200.M096',0,'IDR',1,'101','K001','BACKFILL2025 CI UNIT KE-1 P331/11/25')" | Out-Null
Exec "insert into tbyr2 (voucher,urut,bukti_id,nilai_bayar,nilai_bayar_idr,acc_bayar,flag_order) values ('25122004R009R',1,'10103251100061',50000000,50000000,'103-001',1)" | Out-Null
Exec "commit" | Out-Null
Snap "SESUDAH BACKFILL"

Write-Host "`n=== VERIFIKASI: tbyr faktur Metro total (harus 344.355.300 = lunas) ==="
Write-Host ("  tbyr_total=" + (Scal "select cast(sum(nilai_bayar_idr) as numeric(18,2)) from tbyr2 where bukti_id='10103251100061'"))
$cn.Close()
