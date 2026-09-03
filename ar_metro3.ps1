$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. TBYR1 pembayaran Metro Motor (vendor_id=200.M096) Nov-Des 2025 + join tbyr2" @"
select left(t1.voucher,18) voucher, left(isnull(t1.voucher_manual,''),16) vm, left(isnull(t1.giro_voucher,''),16) giro, cast(t1.tgl as date) tgl, t1.flag_bayar, t1.flag_vendor,
 left(t2.bukti_id,18) bukti, cast(t2.nilai_bayar_idr as numeric(18,2)) nb_idr, left(isnull(t1.gl_reff,''),18) gl_reff
from tbyr1 t1 left join tbyr2 t2 on t2.voucher=t1.voucher
where t1.vendor_id='200.M096' and t1.tgl>='2025-11-01' and t1.tgl<'2026-01-01' order by t1.tgl
"@

Qry "2. Cari R117/R009 di TBYR1 (semua kolom voucher/giro)" @"
select left(voucher,18) voucher, left(isnull(voucher_manual,''),16) vm, left(isnull(giro_voucher,''),16) giro, vendor_id, cast(tgl as date) tgl
from tbyr1 where voucher like '%R117%' or voucher_manual like '%R117%' or giro_voucher like '%R117%'
  or voucher like '%R009%' or voucher_manual like '%R009%' or giro_voucher like '%R009%'
"@

Qry "3. Cari R117/R009 di AR_TRANS (faktur/retur)" @"
select left(order_client,18) order_client, left(isnull(bukti_reff,''),16) bukti_reff, cust_id, cast(tgl as date) tgl, tipe_trans, cast(ttl_netto as numeric(18,2)) ttl
from ar_trans where order_client like '%R117%' or bukti_reff like '%R117%' or order_client like '%R009%' or bukti_reff like '%R009%'
"@

Qry "4. GL 103-001 Metro Motor: total kredit(bayar) vs faktur - saldo bersih?" @"
select left(doc_reff,16) faktur, cast(sum(debet) as numeric(18,2)) db_faktur, cast(sum(kredit) as numeric(18,2)) kr_bayar, cast(sum(debet)-sum(kredit) as numeric(18,2)) saldo
from gl_journal where posting='P' and account_id='103-001' and ket like '%METRO%'
group by doc_reff order by doc_reff
"@
$cn.Close()
