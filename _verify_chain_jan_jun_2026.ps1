$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Q([string]$sql){
  $m=$c.CreateCommand(); $m.CommandText=$sql; $m.CommandTimeout=180
  $rd=$m.ExecuteReader(); $rows=@()
  while($rd.Read()){ $row=@{}; for($i=0;$i -lt $rd.FieldCount;$i++){ $row[$rd.GetName($i)]=$rd.GetValue($i) }; $rows+=,$row }
  $rd.Close(); return $rows
}

# 1. Daftar akun persediaan yg dipakai
$accs = Q "select distinct persediaan from im_product_group where persediaan is not null order by persediaan"
Write-Output "== Daftar akun persediaan =="
foreach($a in $accs){ Write-Output ("  "+$a['persediaan']) }

$months = @('2026-01-01','2026-02-01','2026-03-01','2026-04-01','2026-05-01','2026-06-01','2026-07-01')
$monthnames=@('Jan','Feb','Mar','Apr','Mei','Jun')

Write-Output ""
Write-Output "== CEK 1: Mutasi Stok (SINV) vs Mutasi Ledger (GL) per akun per bulan =="
Write-Output "(format: bulan | sinv_open | sinv_close | mutasi_sinv | mutasi_gl | selisih)"

foreach($a in $accs){
  $acc = $a['persediaan']
  Write-Output ""
  Write-Output "--- Akun $acc ---"
  for($i=0; $i -lt 6; $i++){
    $m0=$months[$i]; $m1=$months[$i+1]; $mend = (Get-Date $m1).AddDays(-1).ToString('yyyy-MM-dd')
    $sql = @"
select
  cast(isnull((select sum(sv.nilai) from sinv sv join im_produk ip on ip.produk_id=sv.stok_id join im_product_group ipg on ipg.kode_group=ip.group_product where ipg.persediaan='$acc' and sv.periode='$m0'),0) as numeric(20,2)) sinv_open,
  cast(isnull((select sum(sv.nilai) from sinv sv join im_produk ip on ip.produk_id=sv.stok_id join im_product_group ipg on ipg.kode_group=ip.group_product where ipg.persediaan='$acc' and sv.periode='$m1'),0) as numeric(20,2)) sinv_close,
  cast(isnull((select sum(g.debet-g.kredit) from gl_journal g where g.account_id='$acc' and g.tgl between '$m0' and '$mend'),0) as numeric(20,2)) gl_mutasi
"@
    $r = Q $sql
    $so=$r[0]['sinv_open']; $sc=$r[0]['sinv_close']; $gm=$r[0]['gl_mutasi']
    $sm = $sc - $so
    $sel = $gm - $sm
    $flag = if([Math]::Abs($sel) -gt 1000){" <<< SELISIH"}else{""}
    Write-Output ("  {0} | open={1:N2} | close={2:N2} | mutasi_sinv={3:N2} | mutasi_gl={4:N2} | selisih={5:N2}{6}" -f $monthnames[$i],$so,$sc,$sm,$gm,$sel,$flag)
  }
}

Write-Output ""
Write-Output "== CEK 2: Selisih KUMULATIF (GL total vs SINV total) di tiap titik snapshot Jan1..Jul1 -- kalau KONSTAN = rantai sehat (offset lama diketahui), kalau LONCAT di titik tertentu = rantai putus di bulan itu =="
foreach($a in $accs){
  $acc = $a['persediaan']
  Write-Output ""
  Write-Output "--- Akun $acc ---"
  # ambil opening tahunan GL sekali
  $glopen = Q "select cast(isnull((select AmountDebet-AmountCredit from gl_balance where AccountCode='$acc' and Period='2026-01-01'),0) as numeric(20,2)) v"
  $glOpening2026 = $glopen[0]['v']
  for($i=0; $i -lt 7; $i++){
    $mX = $months[$i]
    $sinv = Q "select cast(isnull((select sum(sv.nilai) from sinv sv join im_produk ip on ip.produk_id=sv.stok_id join im_product_group ipg on ipg.kode_group=ip.group_product where ipg.persediaan='$acc' and sv.periode='$mX'),0) as numeric(20,2)) v"
    $sinvVal = $sinv[0]['v']
    if($i -eq 0){
      $glVal = $glOpening2026
    } else {
      $mPrevEnd = (Get-Date $mX).AddDays(-1).ToString('yyyy-MM-dd')
      $glmut = Q "select cast(isnull((select sum(g.debet-g.kredit) from gl_journal g where g.account_id='$acc' and g.tgl between '2026-01-01' and '$mPrevEnd'),0) as numeric(20,2)) v"
      $glVal = $glOpening2026 + $glmut[0]['v']
    }
    $sel = $glVal - $sinvVal
    Write-Output ("  snapshot {0} | gl={1:N2} | sinv={2:N2} | selisih_kumulatif={3:N2}" -f $mX,$glVal,$sinvVal,$sel)
  }
}
$c.Close()
Write-Output ""
Write-Output "SELESAI"
