# DIAGNOSTIC SCRIPT - All 8 Gates
# Run in 32-bit PowerShell

param([string]$OutDir = "c:\BTV\debug")
$dsn="vsp"; $uid="dba"; $pwd="jakarta"

function Run {
    param([string]$n, [string]$sql, [string]$f)
    Write-Host "`n[$n] Running..." -ForegroundColor Yellow
    try {
        $c = New-Object System.Data.Odbc.OdbcConnection("Driver={Adaptive Server Anywhere 9.0};DSN=$dsn;UID=$uid;PWD=$pwd")
        $c.Open()
        $cmd = $c.CreateCommand(); $cmd.CommandText = $sql
        $r = $cmd.ExecuteReader()
        $o = @()
        $cols = @()
        for ($i = 0; $i -lt $r.FieldCount; $i++) { $cols += $r.GetName($i) }
        $o += ($cols -join "`t")
        while ($r.Read()) {
            $row = @()
            for ($i = 0; $i -lt $r.FieldCount; $i++) {
                $val = $r[$i]
                if ($val -eq [DBNull]::Value) { $val = "NULL" }
                $row += $val
            }
            $o += ($row -join "`t")
        }
        $r.Close(); $c.Close()
        $o | Out-File -FilePath $f -Encoding UTF8
        Write-Host "[$n] ✓ Done - $($o.Count) rows -> $f" -ForegroundColor Green
    } catch {
        Write-Host "[$n] ✗ Error: $_" -ForegroundColor Red
    }
}

Write-Host "========== DIAGNOSTIC - ALL 8 GATES ==========" -ForegroundColor Cyan

$q1 = "SELECT ISNULL(im_product_group.penjualan, 'NULL') as penjualan, ISNULL(im_produk.group_product, 'NULL') as group_product, COUNT(*) as jumlah, SUM(tsales2.kotor) as total FROM tsales2 JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id JOIN im_produk ON tsales2.stok_id = im_produk.produk_id JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group WHERE tsales1.tipe_trans <> '33' GROUP BY im_product_group.penjualan, im_produk.group_product ORDER BY im_product_group.penjualan"
Run "GATE1" $q1 "$OutDir\diag_penjualan_kombinasi.txt"

$q2 = "SELECT ISNULL(im_produk.group_product, 'NULL') as group_product, COUNT(*) as jumlah, SUM(tsales2.kotor) as total FROM tsales2 JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id JOIN im_produk ON tsales2.stok_id = im_produk.produk_id WHERE tsales1.tipe_trans <> '33' GROUP BY im_produk.group_product ORDER BY total DESC"
Run "GATE2" $q2 "$OutDir\diag_group_product_agregasi.txt"

$q3 = "SELECT ISNULL(im_produk.group_product, 'NULL') as group_product, COUNT(*) as jumlah, SUM(tsales2.kotor) as total FROM tsales2 JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id JOIN im_produk ON tsales2.stok_id = im_produk.produk_id WHERE tsales1.tipe_trans <> '33' AND im_produk.group_product NOT IN ('JS', 'SP', 'UNIT') AND im_produk.group_product IS NOT NULL GROUP BY im_produk.group_product ORDER BY total DESC"
Run "GATE3" $q3 "$OutDir\diag_orphan_category.txt"

$q4 = "SELECT TOP 50 tsales1.bukti_id, tsales1.tgl, SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) as unit_idr, SUM(CASE WHEN im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) as jasa_idr, SUM(CASE WHEN im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END) as spare_idr, SUM(tsales2.kotor) as kotor_idr FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id JOIN im_produk ON tsales2.stok_id = im_produk.produk_id JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group WHERE tsales1.tipe_trans <> '33' GROUP BY tsales1.bukti_id, tsales1.tgl HAVING ABS((SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) + SUM(CASE WHEN im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) + SUM(CASE WHEN im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END)) - SUM(tsales2.kotor)) > 1 ORDER BY bukti_id DESC"
Run "GATE4" $q4 "$OutDir\diag_balance_not_ok.txt"

$q5 = "SELECT TOP 50 tsales1.bukti_id, tsales1.tgl, COUNT(DISTINCT tsales1.curr_id) as currency_count FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id WHERE tsales1.tipe_trans <> '33' GROUP BY tsales1.bukti_id, tsales1.tgl HAVING COUNT(DISTINCT tsales1.curr_id) > 0 ORDER BY currency_count DESC"
Run "GATE5" $q5 "$OutDir\diag_currency_integrity.txt"

$q6 = "SELECT 'Existing' as source, CAST(SUM(tsales2.kotor) AS DECIMAL(18,2)) as kotor_total FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id WHERE tsales1.tipe_trans <> '33' UNION ALL SELECT 'New', CAST(SUM(tsales2.kotor) AS DECIMAL(18,2)) FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id WHERE tsales1.tipe_trans <> '33'"
Run "GATE6" $q6 "$OutDir\diag_reconciliation_existing.txt"

$q7 = "SELECT 'Current Month' as period, SUM(tsales2.kotor) as revenue FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id WHERE tsales1.tipe_trans <> '33' AND YEAR(tsales1.tgl) = YEAR(GETDATE()) AND MONTH(tsales1.tgl) = MONTH(GETDATE()) UNION ALL SELECT 'Last 3M', SUM(tsales2.kotor) FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id WHERE tsales1.tipe_trans <> '33' AND tsales1.tgl >= DATEADD(MONTH, -3, GETDATE()) UNION ALL SELECT 'Last 6M', SUM(tsales2.kotor) FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id WHERE tsales1.tipe_trans <> '33' AND tsales1.tgl >= DATEADD(MONTH, -6, GETDATE()) UNION ALL SELECT 'Last 12M', SUM(tsales2.kotor) FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id WHERE tsales1.tipe_trans <> '33' AND tsales1.tgl >= DATEADD(MONTH, -12, GETDATE())"
Run "GATE7" $q7 "$OutDir\diag_historical_regression_test.txt"

$q8 = "SELECT COUNT(*) as total_rows, COUNT(*) - COUNT(im_produk.group_product) as null_group_product, COUNT(*) - COUNT(im_product_group.penjualan) as null_penjualan FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id JOIN im_produk ON tsales2.stok_id = im_produk.produk_id LEFT JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group WHERE tsales1.tipe_trans <> '33'"
Run "GATE8" $q8 "$OutDir\diag_null_data_quality.txt"

Write-Host ""
Write-Host "========== COMPLETE ==========" -ForegroundColor Cyan
Get-ChildItem -Path "$OutDir\diag_*.txt" -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-5) } | ForEach-Object { Write-Host "  ✓ $($_.Name)" }
