$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Val($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=500; $c.CommandText=$sql; try{$v=$c.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return 0}; return [decimal]$v}catch{return "ERR:"+$_.Exception.Message} }
function N($d){ if($d -is [string]){return $d}; return ('{0:N2}' -f $d) }

# DPB per bulan = tbyr valas flag_bayar 1/2 melekat faktur AP, TANPA pasangan 226-debet di bulan itu
function DPB($m1,$m2){ Val @"
select isnull(sum(t2.nilai_bayar_idr),0)
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.tgl>='$m1' and t1.tgl<='$m2' and t1.flag_bayar in (1,2)
  and abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1
  and exists(select 1 from ap_trans a2 where a2.order_client=t2.bukti_id)
  and (select count(*) from gl_journal g where g.posting='P' and g.account_id in ('226-001','226-006') and g.debet>0
        and abs(g.debet - t2.nilai_bayar_idr) < 1 and g.tgl>='$m1' and g.tgl<='$m2')=0
"@ }

$months = @(@('Feb','2026-02-01','2026-02-28'),@('Mar','2026-03-01','2026-03-31'),@('Apr','2026-04-01','2026-04-30'),@('Mei','2026-05-01','2026-05-31'),@('Jun','2026-06-01','2026-06-30'))
$cum=0
Write-Host ("{0,-4} | {1,22} | {2,22}" -f 'Bln','DPB bulan ini','DPB kumulatif')
Write-Host ("-"*56)
foreach($m in $months){ $v=DPB $m[1] $m[2]; if($v -isnot [string]){$cum+=$v}; Write-Host ("{0,-4} | {1,22} | {2,22}" -f $m[0],(N $v),(N $cum)) }
Write-Host ""
Write-Host "Gap AP dilaporkan: Feb -1.149,70jt  Apr -1.324,50jt  Mei -1.930,30jt  Jun -2.928,23jt"
$cn.Close()
