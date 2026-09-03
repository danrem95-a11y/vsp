$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=localhost;port=2638);ENG=vsp;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong / LULUS>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

foreach($per in @(@('Jan','2026-01-01','2026-01-31'), @('Feb','2026-02-01','2026-02-28'))){
 $lbl=$per[0]; $m1=$per[1]; $m2=$per[2]
 $basis = if($lbl -eq 'Jan'){'2026-01-01'}else{'2026-02-01'}
 Qry "[$lbl] G3 WIP-Out '88' menyimpang dari basis SINV awal bulan ($basis, dev>1000)" @"
select x.stok_id, cast(x.hpp_out as numeric(18,2)) hpp_out_skrg, cast(x.basis_awal as numeric(18,2)) basis_awal
from (select s2.stok_id, max(s2.hpp) hpp_out,
        (select sum(hpp_avg) from sinv where stok_id=s2.stok_id and periode='$basis') basis_awal
      from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
      where s1.tipe_trans='88' and s1.tgl between '$m1' and '$m2' and isnull(s2.evap,'')<>''
      group by s2.stok_id) x
where x.basis_awal is not null and abs(isnull(x.hpp_out,0)-isnull(x.basis_awal,0))>1000 order by x.stok_id
"@
}

Qry "Recency: aktivitas refresh (max tgl per modul + counts Jan/Feb)" @"
select 'gl_journal' tbl, cast(max(tgl) as date) maxtgl,
  sum(case when tgl between '2026-01-01' and '2026-01-31' then 1 else 0 end) jan,
  sum(case when tgl between '2026-02-01' and '2026-02-28' then 1 else 0 end) feb from gl_journal where posting='P'
union all
select 'tsales1', cast(max(tgl) as date),
  sum(case when tgl between '2026-01-01' and '2026-01-31' then 1 else 0 end),
  sum(case when tgl between '2026-02-01' and '2026-02-28' then 1 else 0 end) from tsales1
"@

Qry "Recency: last-modified refresh log (jika ada REFRESH_LOG / USER_LOG)" @"
select 'sinv rows' info, count(*) n, cast(max(periode) as date) maxper from sinv
"@
$cn.Close()
