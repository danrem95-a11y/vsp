$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out = @()
$out += "=== DIAG109c: Root cause hunt - simple queries + PS math - $(Get-Date) ==="

$out += ""
$out += "=== A: GL 102-001 Jan 2026 summary by modul ==="
$cmd.CommandText = "SELECT modul_id, COUNT(*) as cnt, SUM(debet) as Dr, SUM(kredit) as Cr FROM gl_journal WHERE account_id='102-001' AND tgl BETWEEN '2026-01-01' AND '2026-01-31' GROUP BY modul_id ORDER BY Cr DESC"
$r = $cmd.ExecuteReader(); $rows = @()
while ($r.Read()) { $rows += "$($r[0]) | cnt=$($r[1]) | Dr=$($r[2]) | Cr=$($r[3])" }
$r.Close(); $out += $rows

$out += ""
$out += "=== B: tstok tipe 88 TR products Jan 2026 ==="
$cmd.CommandText = "SELECT t2.stok_id, SUM(t2.qty) as qty, SUM(t2.netto*ISNULL(t1.kurs,1)) as netto_rp, SUM(t2.netto_hpp) as netto_hpp FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t2.stok_id LIKE 'TR.%' AND t1.tipe_trans='88' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y' GROUP BY t2.stok_id"
$r2 = $cmd.ExecuteReader(); $consin = @{}
$out += "stok_id | consin_qty | consin_rp(netto*kurs) | consin_hpp(netto_hpp)"
while ($r2.Read()) {
    $sid = $r2[0]; $qty = $r2[1]; $rp = if($r2[2]-ne[DBNull]::Value){[decimal]$r2[2]}else{0}; $hpp = if($r2[3]-ne[DBNull]::Value){[decimal]$r2[3]}else{0}
    $consin[$sid] = @{qty=$qty; rp=$rp; hpp=$hpp}
    $out += "$sid | $qty | $rp | $hpp"
}
$r2.Close()

$out += ""
$out += "=== C: SINV Jan for TR products ==="
$cmd.CommandText = "SELECT stok_id, SUM(qty) as qty, SUM(nilai) as nilai FROM sinv WHERE MONTH(periode)=1 AND YEAR(periode)=2026 AND stok_id LIKE 'TR.%' GROUP BY stok_id"
$r3 = $cmd.ExecuteReader(); $sinvJan = @{}
$out += "stok_id | jan_qty | jan_nilai"
while ($r3.Read()) {
    $sid = $r3[0]; $q = if($r3[1]-ne[DBNull]::Value){[decimal]$r3[1]}else{0}; $n = if($r3[2]-ne[DBNull]::Value){[decimal]$r3[2]}else{0}
    $sinvJan[$sid] = @{qty=$q; nilai=$n}
    $out += "$sid | $q | $n"
}
$r3.Close()

$out += ""
$out += "=== D: tstok tipe 02/12/09 TR products Jan 2026 (beli/ret_beli/mutasi_in) ==="
$cmd.CommandText = "SELECT t2.stok_id, t1.tipe_trans, SUM(t2.qty) as qty, SUM(t2.netto*ISNULL(t1.kurs,1)) as netto_rp, SUM(ABS(t2.netto_hpp)) as netto_hpp, SUM(ABS(t2.biaya_ekspedisi)*ABS(ISNULL(t2.qty,0))) as ekspedisi FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t2.stok_id LIKE 'TR.%' AND t1.tipe_trans IN ('02','12','09','05') AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y' GROUP BY t2.stok_id, t1.tipe_trans ORDER BY t2.stok_id, t1.tipe_trans"
$r4 = $cmd.ExecuteReader(); $stok = @{}
$out += "stok_id | tipe | qty | netto_rp | netto_hpp | ekspedisi"
while ($r4.Read()) {
    $sid = $r4[0]; $tp = $r4[1]; $q = if($r4[2]-ne[DBNull]::Value){[decimal]$r4[2]}else{0}; $rp = if($r4[3]-ne[DBNull]::Value){[decimal]$r4[3]}else{0}; $hpp = if($r4[4]-ne[DBNull]::Value){[decimal]$r4[4]}else{0}; $exped = if($r4[5]-ne[DBNull]::Value){[decimal]$r4[5]}else{0}
    if (-not $stok.ContainsKey($sid)) { $stok[$sid] = @{} }
    $stok[$sid][$tp] = @{qty=$q; rp=$rp; hpp=$hpp; exped=$exped}
    $out += "$sid | $tp | $q | $rp | $hpp | $exped"
}
$r4.Close()

$out += ""
$out += "=== E: tsales tipe 22/88 TR products Jan 2026 (jual/consout) + current hpp ==="
$cmd.CommandText = "SELECT t2.stok_id, t1.tipe_trans, SUM(t2.qty) as qty, SUM(t2.qty*ISNULL(t2.hpp,0)) as nilai_hpp FROM tsales1 t1, tsales2 t2 WHERE t1.bukti_id=t2.bukti_id AND t2.stok_id LIKE 'TR.%' AND t1.tipe_trans IN ('22','88','32','26','36') AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND t1.order_oke='Y' GROUP BY t2.stok_id, t1.tipe_trans ORDER BY t2.stok_id, t1.tipe_trans"
$r5 = $cmd.ExecuteReader(); $sales = @{}
$out += "stok_id | tipe | qty | nilai_hpp"
while ($r5.Read()) {
    $sid = $r5[0]; $tp = $r5[1]; $q = if($r5[2]-ne[DBNull]::Value){[decimal]$r5[2]}else{0}; $nh = if($r5[3]-ne[DBNull]::Value){[decimal]$r5[3]}else{0}
    if (-not $sales.ContainsKey($sid)) { $sales[$sid] = @{} }
    $sales[$sid][$tp] = @{qty=$q; nilai_hpp=$nh}
    $out += "$sid | $tp | $q | $nh"
}
$r5.Close()

$out += ""
$out += "=== F: SINV Feb for TR products ==="
$cmd.CommandText = "SELECT stok_id, qty, nilai, hpp_avg FROM sinv WHERE MONTH(periode)=2 AND YEAR(periode)=2026 AND stok_id LIKE 'TR.%' ORDER BY stok_id"
$r6 = $cmd.ExecuteReader(); $sinvFeb = @{}
$out += "stok_id | feb_qty | feb_nilai | feb_hpp_avg"
while ($r6.Read()) {
    $sid = $r6[0]; $q = if($r6[1]-ne[DBNull]::Value){[decimal]$r6[1]}else{0}; $n = if($r6[2]-ne[DBNull]::Value){[decimal]$r6[2]}else{0}; $h = if($r6[3]-ne[DBNull]::Value){[decimal]$r6[3]}else{0}
    $sinvFeb[$sid] = @{qty=$q; nilai=$n; hpp_avg=$h}
    $out += "$sid | $q | $n | $h"
}
$r6.Close()

$conn.Close()

$out += ""
$out += "=== G: Compute hppx and consin_rp vs consin*hppx per TR product ==="

$totalConsinRp = 0
$totalConsinHppx = 0
$allSids = ($sinvJan.Keys + $consin.Keys) | Select-Object -Unique
foreach ($sid in ($allSids | Sort-Object)) {
    $awal = if($sinvJan.ContainsKey($sid)){$sinvJan[$sid].qty}else{0}
    $awal_rp = if($sinvJan.ContainsKey($sid)){$sinvJan[$sid].nilai}else{0}
    $beli = if($stok.ContainsKey($sid) -and $stok[$sid].ContainsKey('02')){$stok[$sid]['02'].qty}else{0}
    $beli_rp = if($stok.ContainsKey($sid) -and $stok[$sid].ContainsKey('02')){$stok[$sid]['02'].rp + $stok[$sid]['02'].exped}else{0}
    $ret_beli = if($stok.ContainsKey($sid) -and $stok[$sid].ContainsKey('12')){$stok[$sid]['12'].qty}else{0}
    $ret_beli_rp = if($stok.ContainsKey($sid) -and $stok[$sid].ContainsKey('12')){$stok[$sid]['12'].hpp}else{0}
    $mutasi_in = if($stok.ContainsKey($sid) -and $stok[$sid].ContainsKey('09')){$stok[$sid]['09'].qty}else{0}
    $mutasi_in_rp = if($stok.ContainsKey($sid) -and $stok[$sid].ContainsKey('09')){$stok[$sid]['09'].rp}else{0}
    $consin_qty_v = if($consin.ContainsKey($sid)){$consin[$sid].qty}else{0}
    $consin_rp_v = if($consin.ContainsKey($sid)){$consin[$sid].rp}else{0}

    $denom = $awal + $beli + $mutasi_in - $ret_beli
    if ($denom -ne 0) {
        $hppx = ($awal_rp + $beli_rp + $mutasi_in_rp - $ret_beli_rp) / $denom
    } else { $hppx = 0 }

    if ($consin_qty_v -ne 0) {
        $consin_hppx = $consin_qty_v * $hppx
        $diff = $consin_rp_v - $consin_hppx
        $totalConsinRp += $consin_rp_v
        $totalConsinHppx += $consin_hppx
        $out += "$sid | consin_qty=$consin_qty_v | consin_rp=$consin_rp_v | hppx=$([Math]::Round($hppx,2)) | consin*hppx=$([Math]::Round($consin_hppx,2)) | DIFF=$([Math]::Round($diff,2))"
    }
}
$out += "TOTAL consin_rp     = $totalConsinRp"
$out += "TOTAL consin*hppx   = $totalConsinHppx"
$out += "TOTAL diff          = $($totalConsinRp - $totalConsinHppx)"

$out += ""
$out += "=== H: GL AS debet total for 102-001 vs sum of beli_rp + consin_rp ==="
$totalBeliRp = 0
$totalConsinRpH = 0
$totalMutInRp = 0
foreach ($sid in $sinvJan.Keys) {
    if ($stok.ContainsKey($sid)) {
        if ($stok[$sid].ContainsKey('02')) { $totalBeliRp += $stok[$sid]['02'].rp + $stok[$sid]['02'].exped }
        if ($stok[$sid].ContainsKey('09')) { $totalMutInRp += $stok[$sid]['09'].rp }
    }
    if ($consin.ContainsKey($sid)) { $totalConsinRpH += $consin[$sid].rp }
}
$out += "Sum beli_rp (tipe 02+05) for TR   = $totalBeliRp"
$out += "Sum consin_rp (tipe 88) for TR     = $totalConsinRpH"
$out += "Sum mutasi_in_rp (tipe 09) for TR  = $totalMutInRp"
$out += "Sum debet from stok                = $($totalBeliRp + $totalConsinRpH + $totalMutInRp)"

$out += ""
$out += "=== I: GL kredit HP for 102-001 vs sum of jual*current_hpp ==="
$totalJualHpp = 0; $totalJualHpp22 = 0; $totalJualHpp88 = 0
foreach ($sid in $sinvJan.Keys) {
    if ($sales.ContainsKey($sid)) {
        if ($sales[$sid].ContainsKey('22')) { $totalJualHpp22 += $sales[$sid]['22'].nilai_hpp }
        if ($sales[$sid].ContainsKey('88')) { $totalJualHpp88 += $sales[$sid]['88'].nilai_hpp }
    }
}
$out += "Sum jual*hpp (tipe 22) for TR      = $totalJualHpp22"
$out += "Sum consout*hpp (tipe 88) for TR   = $totalJualHpp88"

$out | Out-File -FilePath "c:\BTV\debug\diag109c_out.txt" -Encoding UTF8
Write-Host "Done: c:\BTV\debug\diag109c_out.txt"
