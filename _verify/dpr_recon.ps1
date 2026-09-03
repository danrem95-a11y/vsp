$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Val($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=500; $c.CommandText=$sql; try{$v=$c.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return 0}; return [decimal]$v}catch{return "ERR:"+$_.Exception.Message} }
function N($d){ if($d -is [string]){return $d}; return ('{0:N2}' -f $d) }

# DPR per bulan = tbyr flag_bayar 1/2 melekat faktur AR (ar_trans), TANPA pasangan 103-001-kredit di bulan itu
function DPR($m1,$m2,$valasOnly){
 $vc = if($valasOnly){"and abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1"}else{""}
 Val @"
select isnull(sum(t2.nilai_bayar_idr),0)
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.tgl>='$m1' and t1.tgl<='$m2' and t1.flag_bayar in (1,2) $vc
  and exists(select 1 from ar_trans a2 where a2.order_client=t2.bukti_id)
  and (select count(*) from gl_journal g where g.posting='P' and g.account_id='103-001' and g.kredit>0
        and abs(g.kredit - t2.nilai_bayar_idr) < 1 and g.tgl>='$m1' and g.tgl<='$m2')=0
"@ }

$months = @(@('Jan','2026-01-01','2026-01-31'),@('Feb','2026-02-01','2026-02-28'),@('Mar','2026-03-01','2026-03-31'),@('Apr','2026-04-01','2026-04-30'),@('Mei','2026-05-01','2026-05-31'),@('Jun','2026-06-01','2026-06-30'))
$ca=0; $cv=0
Write-Host ("{0,-4} | {1,18} | {2,18} | {3,18} | {4,18}" -f 'Bln','DPR-all bln','DPR-all kum','DPR-valas bln','DPR-valas kum')
Write-Host ("-"*82)
foreach($m in $months){ $a=DPR $m[1] $m[2] $false; $v=DPR $m[1] $m[2] $true; if($a -isnot [string]){$ca+=$a}; if($v -isnot [string]){$cv+=$v}; Write-Host ("{0,-4} | {1,18} | {2,18} | {3,18} | {4,18}" -f $m[0],(N $a),(N $ca),(N $v),(N $cv)) }
Write-Host ""
Write-Host "Gap AR: Jan -76,61jt  Feb -297,28jt  Apr -459,86jt  Mei -698,96jt  Jun -992,18jt"
$cn.Close()
