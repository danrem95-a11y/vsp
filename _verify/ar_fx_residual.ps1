$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Val($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=500; $c.CommandText=$sql; try{$v=$c.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return 0}; return [decimal]$v}catch{return "ERR:"+$_.Exception.Message} }
function N($d){ if($d -is [string]){return $d}; return ('{0:N2}' -f $d) }

# Untuk penerimaan VALAS AR (flag 1/2) yg ADA pasangan 103-kredit:
#   A = yg dikurangi opname (nilai_bayar_idr)
#   B = yg di-kredit GL 103-001 utk voucher penerimaan itu
#   A-B = selisih kurs realisasi (residual)
function AminusB($m1,$m2){ Val @"
select isnull(sum(t2.nilai_bayar_idr),0)
     - isnull((select sum(g.kredit-g.debet) from gl_journal g
               where g.posting='P' and g.account_id='103-001'
                 and g.voucher in (select t1b.voucher from tbyr1 t1b join tbyr2 t2b on t2b.voucher=t1b.voucher
                     where t1b.tgl>='$m1' and t1b.tgl<='$m2' and t1b.flag_bayar in (1,2)
                       and abs(t2b.nilai_bayar - t2b.nilai_bayar_idr) >= 1
                       and exists(select 1 from ar_trans a2 where a2.order_client=t2b.bukti_id))),0)
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.tgl>='$m1' and t1.tgl<='$m2' and t1.flag_bayar in (1,2)
  and abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1
  and exists(select 1 from ar_trans a2 where a2.order_client=t2.bukti_id)
"@ }

$months = @(@('Jan','2026-01-01','2026-01-31'),@('Feb','2026-02-01','2026-02-28'),@('Mar','2026-03-01','2026-03-31'),@('Apr','2026-04-01','2026-04-30'),@('Mei','2026-05-01','2026-05-31'),@('Jun','2026-06-01','2026-06-30'))
$cum=0
Write-Host ("{0,-4} | {1,20} | {2,20}" -f 'Bln','FX-residual bln','Kumulatif')
Write-Host ("-"*50)
foreach($m in $months){ $v=AminusB $m[1] $m[2]; if($v -isnot [string]){$cum+=$v}; Write-Host ("{0,-4} | {1,20} | {2,20}" -f $m[0],(N $v),(N $cum)) }
Write-Host ""
Write-Host "Target residual AR (gap - DPR): Feb +61,6  Mei +42,0  Jun +57,0  (kumulatif ~160,63jt)"
$cn.Close()
