$cs = "DSN=vsp;UID=dba;PWD=jakarta"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. LOCAL - semua TBYR utk faktur 10103251100061 (Metro) urut tgl" @"
select cast(t1.tgl as date) tgl, left(t1.voucher,16) voucher, t1.flag_bayar, t1.flag_vendor, t1.vendor_id, t1.kolektor_id, t1.kas_id, t1.curr_id, cast(t2.nilai_bayar_idr as numeric(18,2)) nb_idr, t2.acc_bayar, t2.flag_order, t2.urut
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t2.bukti_id='10103251100061' order by t1.tgl
"@

Qry "2. LOCAL - semua TBYR utk faktur 10105250700002 (Bingshan) urut tgl" @"
select cast(t1.tgl as date) tgl, left(t1.voucher,16) voucher, t1.flag_bayar, t1.flag_vendor, t1.vendor_id, t1.kolektor_id, t1.kas_id, t1.curr_id, cast(t2.nilai_bayar_idr as numeric(18,2)) nb_idr, t2.acc_bayar, t2.flag_order, t2.urut
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t2.bukti_id='10105250700002' order by t1.tgl
"@

Qry "3. LOCAL - record 2025 yg HILANG di prod (tbyr Metro/Bingshan tgl 2025)" @"
select left(t2.bukti_id,16) faktur, cast(t1.tgl as date) tgl, left(t1.voucher,16) voucher, cast(t2.nilai_bayar_idr as numeric(18,2)) nb_idr, t1.vendor_id
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t2.bukti_id in ('10103251100061','10105250700002') and t1.tgl>='2025-01-01' and t1.tgl<'2026-01-01' order by t2.bukti_id, t1.tgl
"@
$cn.Close()
