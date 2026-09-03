$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection($cs); $cn.Open()
function Q([string]$sql){
  $m=$cn.CreateCommand(); $m.CommandText=$sql; $m.CommandTimeout=280
  $rd=$m.ExecuteReader(); $rows=@()
  while($rd.Read()){ $row=@{}; for($i=0;$i -lt $rd.FieldCount;$i++){ $row[$rd.GetName($i)]=$rd.GetValue($i) }; $rows+=,$row }
  $rd.Close(); return $rows
}

# AR: cari voucher DP/manual (spt DPR pattern lama) yg GL 103-001 tapi tak match opname formula, per bulan Apr-Jun
Write-Output "== AR: voucher gl_journal 103-001 per bulan yg TIDAK match hasil opname (kandidat penyebab gap baru) =="
foreach($p in @(@('Apr','2026-04-01','2026-04-30'),@('Mei','2026-05-01','2026-05-31'),@('Jun','2026-06-01','2026-06-30'))){
  $lbl=$p[0]; $t1=$p[1]; $t2=$p[2]
  Write-Output ""
  Write-Output "--- $lbl ---"
  $sql = @"
select g.voucher, g.modul_id, cast(sum(g.debet-g.kredit) as numeric(16,2)) net, min(g.tgl) tgl, min(g.ket) ket
  from gl_journal g
 where g.account_id='103-001' and g.posting='P' and g.tgl between '$t1' and '$t2'
   and not exists (select 1 from AR_TRANS at where at.order_client=g.voucher and at.tipe_trans in ('22','32','33','26','36') and at.order_oke='Y')
 group by g.voucher, g.modul_id
 having abs(sum(g.debet-g.kredit)) > 100
 order by abs(sum(g.debet-g.kredit)) desc
"@
  $r = Q $sql
  if($r.Count -eq 0){ Write-Output "  (0 voucher - tidak ada kandidat orphan)" }
  foreach($row in $r){
    Write-Output ("  "+$row['voucher']+" | "+$row['modul_id']+" | net="+('{0:N2}' -f $row['net'])+" | tgl="+$row['tgl']+" | "+$row['ket'])
  }
}

# AP: sama, cari voucher 226-001/226-006 per bulan yg tak match opname (formula AP biasanya berbasis AP_TRANS / sejenis)
Write-Output ""
Write-Output "== AP: voucher gl_journal 226-001/226-006 per bulan dgn nilai besar (top 15, utk screening manual) =="
foreach($p in @(@('Apr','2026-04-01','2026-04-30'),@('Mei','2026-05-01','2026-05-31'),@('Jun','2026-06-01','2026-06-30'))){
  $lbl=$p[0]; $t1=$p[1]; $t2=$p[2]
  Write-Output ""
  Write-Output "--- $lbl (top 15 by |net|) ---"
  $sql = @"
select g.voucher, g.modul_id, cast(sum(g.debet-g.kredit) as numeric(16,2)) net, min(g.tgl) tgl, min(g.ket) ket
  from gl_journal g
 where g.account_id in ('226-001','226-006') and g.posting='P' and g.tgl between '$t1' and '$t2'
 group by g.voucher, g.modul_id
 order by abs(sum(g.debet-g.kredit)) desc
"@
  $r = Q $sql
  $n=0
  foreach($row in $r){
    $n++; if($n -gt 15){break}
    Write-Output ("  "+$row['voucher']+" | "+$row['modul_id']+" | net="+('{0:N2}' -f $row['net'])+" | tgl="+$row['tgl']+" | "+$row['ket'])
  }
}
$cn.Close()
