$csL = "DSN=vsp;UID=dba;PWD=jakarta"
$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$L = New-Object System.Data.Odbc.OdbcConnection $csL; $L.Open()
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Scal($cn,$sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql; try{$v=$c.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return ''}; return [string]$v}catch{return 'ERR:'+$_.Exception.Message} }
function Show($cn,$lbl,$sql){ Write-Host "-- $lbl --"; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql; $rd=$c.ExecuteReader(); while($rd.Read()){$a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=[string]$rd[$i]};Write-Host ("   "+($a -join " | "))}; $rd.Close() }

Write-Host "=== 1. IDENTITAS DB (lokal vs prod beda?) ==="
Write-Host ("  LOKAL: file=" + (Scal $L "select db_property('File')") + " | server=" + (Scal $L "select property('Name')") + " | total_tbyr1=" + (Scal $L "select count(*) from tbyr1"))
Write-Host ("  PROD : file=" + (Scal $P "select db_property('File')") + " | server=" + (Scal $P "select property('Name')") + " | total_tbyr1=" + (Scal $P "select count(*) from tbyr1"))

Write-Host "`n=== 2. Keterangan record Metro 2025 di PROD (RESTORE2025 = dari runbook?) ==="
Show $P "PROD tbyr1 Metro 2025" "select voucher, cast(tgl as date) tgl, left(isnull(keterangan,''),40) ket, isnull(user_id,'') usr from tbyr1 where voucher in ('25112004R117R','25122004R009R')"

Write-Host "`n=== 3. Status BERLUBANG prod SEKARANG (GL bayar 2025 > tbyr 2025) ==="
Show $P "PROD berlubang skrg" @"
select count(*) n_faktur, cast(sum(gl_pay-tbyr_pay) as numeric(18,2)) total from (
 select gj.doc_reff,
  sum(gj.kredit) gl_pay,
  isnull((select sum(t2.nilai_bayar_idr) from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t2.bukti_id=gj.doc_reff and t1.tgl>='2025-01-01' and t1.tgl<'2026-01-01' and t1.flag_bayar in (1,2)),0) tbyr_pay
 from gl_journal gj where gj.posting='P' and gj.account_id='103-001' and gj.kredit>0 and gj.tgl>='2025-01-01' and gj.tgl<'2026-01-01' and isnull(gj.doc_reff,'')<>''
 group by gj.doc_reff
) y where y.gl_pay - y.tbyr_pay > 1
"@
$L.Close(); $P.Close()
