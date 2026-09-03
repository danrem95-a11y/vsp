$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Q([string]$sql){
  $m=$c.CreateCommand(); $m.CommandText=$sql; $m.CommandTimeout=280
  $rd=$m.ExecuteReader(); $rows=@()
  while($rd.Read()){ $row=@{}; for($i=0;$i -lt $rd.FieldCount;$i++){ $row[$rd.GetName($i)]=$rd.GetValue($i) }; $rows+=,$row }
  $rd.Close(); return $rows
}

Write-Output "== CEK 1: Mutasi Stok (SINV) vs Mutasi Ledger (GL) per akun per bulan (satu query, semua akun x bulan) =="
$sql1 = @"
select acc.persediaan as akun, p.idx, p.m0, p.m1,
  cast(isnull((select sum(sv.nilai) from sinv sv join im_produk ip on ip.produk_id=sv.stok_id join im_product_group ipg on ipg.kode_group=ip.group_product where ipg.persediaan=acc.persediaan and sv.periode=p.m0),0) as numeric(20,2)) sinv_open,
  cast(isnull((select sum(sv.nilai) from sinv sv join im_produk ip on ip.produk_id=sv.stok_id join im_product_group ipg on ipg.kode_group=ip.group_product where ipg.persediaan=acc.persediaan and sv.periode=p.m1),0) as numeric(20,2)) sinv_close,
  cast(isnull((select sum(g.debet-g.kredit) from gl_journal g where g.account_id=acc.persediaan and g.tgl between p.m0 and p.mend),0) as numeric(20,2)) gl_mutasi
from (select distinct persediaan from im_product_group where persediaan is not null) acc
cross join (
  select 1 idx, cast('2026-01-01' as date) m0, cast('2026-02-01' as date) m1, cast('2026-01-31' as date) mend union all
  select 2, cast('2026-02-01' as date), cast('2026-03-01' as date), cast('2026-02-28' as date) union all
  select 3, cast('2026-03-01' as date), cast('2026-04-01' as date), cast('2026-03-31' as date) union all
  select 4, cast('2026-04-01' as date), cast('2026-05-01' as date), cast('2026-04-30' as date) union all
  select 5, cast('2026-05-01' as date), cast('2026-06-01' as date), cast('2026-05-31' as date) union all
  select 6, cast('2026-06-01' as date), cast('2026-07-01' as date), cast('2026-06-30' as date)
) p
order by acc.persediaan, p.idx
"@
$r1 = Q $sql1
$monthnames=@{1='Jan';2='Feb';3='Mar';4='Apr';5='Mei';6='Jun'}
$curAcc=$null
foreach($row in $r1){
  if($row['akun'] -ne $curAcc){ Write-Output ""; Write-Output ("--- Akun "+$row['akun']+" ---"); $curAcc=$row['akun'] }
  $so=$row['sinv_open']; $sc=$row['sinv_close']; $gm=$row['gl_mutasi']
  $sm = $sc - $so
  $sel = $gm - $sm
  $flag = if([Math]::Abs($sel) -gt 1000){" <<< SELISIH"}else{""}
  Write-Output ("  {0} | open={1:N2} | close={2:N2} | mutasi_sinv={3:N2} | mutasi_gl={4:N2} | selisih={5:N2}{6}" -f $monthnames[[int]$row['idx']],$so,$sc,$sm,$gm,$sel,$flag)
}

Write-Output ""
Write-Output "== CEK 2: Selisih KUMULATIF (GL total vs SINV total) di tiap titik snapshot Jan1..Jul1 (satu query) =="
$sql2 = @"
select acc.persediaan as akun, p.idx, p.mX,
  cast(isnull((select AmountDebet-AmountCredit from gl_balance where AccountCode=acc.persediaan and Period='2026-01-01'),0) as numeric(20,2)) gl_open_2026,
  cast(isnull((select sum(g.debet-g.kredit) from gl_journal g where g.account_id=acc.persediaan and g.tgl between '2026-01-01' and p.mPrevEnd),0) as numeric(20,2)) gl_mutasi_kumulatif,
  cast(isnull((select sum(sv.nilai) from sinv sv join im_produk ip on ip.produk_id=sv.stok_id join im_product_group ipg on ipg.kode_group=ip.group_product where ipg.persediaan=acc.persediaan and sv.periode=p.mX),0) as numeric(20,2)) sinv_val
from (select distinct persediaan from im_product_group where persediaan is not null) acc
cross join (
  select 1 idx, cast('2026-01-01' as date) mX, cast('2025-12-31' as date) mPrevEnd union all
  select 2, cast('2026-02-01' as date), cast('2026-01-31' as date) union all
  select 3, cast('2026-03-01' as date), cast('2026-02-28' as date) union all
  select 4, cast('2026-04-01' as date), cast('2026-03-31' as date) union all
  select 5, cast('2026-05-01' as date), cast('2026-04-30' as date) union all
  select 6, cast('2026-06-01' as date), cast('2026-05-31' as date) union all
  select 7, cast('2026-07-01' as date), cast('2026-06-30' as date)
) p
order by acc.persediaan, p.idx
"@
$r2 = Q $sql2
$curAcc=$null
foreach($row in $r2){
  if($row['akun'] -ne $curAcc){ Write-Output ""; Write-Output ("--- Akun "+$row['akun']+" ---"); $curAcc=$row['akun'] }
  $idx = [int]$row['idx']
  if($idx -eq 1){
    $glVal = $row['gl_open_2026']
  } else {
    $glVal = $row['gl_open_2026'] + $row['gl_mutasi_kumulatif']
  }
  $sinvVal = $row['sinv_val']
  $sel = $glVal - $sinvVal
  Write-Output ("  snapshot {0} | gl={1:N2} | sinv={2:N2} | selisih_kumulatif={3:N2}" -f $row['mX'],$glVal,$sinvVal,$sel)
}
$c.Close()
Write-Output ""
Write-Output "SELESAI"
