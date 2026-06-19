# diag117_rollback.ps1
# ROLLBACK perbaikan diag117: kembalikan tstok2.biaya_ekspedisi, ap_trans FR,
# dan gl_journal (modul EX) ke kondisi PERSIS sebelum diag117_fix dijalankan,
# memakai isi tabel diag117_backup_* (snapshot PALING AWAL = kondisi asli).
#
# DEFAULT = DRY-RUN. Jalankan dengan -DoUpdate untuk eksekusi.
#   C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -File diag117_rollback.ps1 [-DoUpdate]
param(
    [switch]$DoUpdate = $false,
    [string]$Dsn = "vsp",
    [string]$Uid = "dba",
    [string]$Pwd = "jakarta"
)

$docs   = @('10126040500001','10126040500002')
$frdocs = @('1012604FR05001','1012604FR05002')
$all    = ($docs + $frdocs | ForEach-Object { "'$_'" }) -join ','

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=$Dsn;UID=$Uid;PWD=$Pwd")
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandTimeout = 120
$out = @()
$mode = if ($DoUpdate) { "EKSEKUSI" } else { "DRY-RUN (tidak ada perubahan)" }
$out += "================ diag117 ROLLBACK - mode: $mode - " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " ================"

function Exec($sql)   { $script:cmd.CommandText = $sql; [void]$script:cmd.ExecuteNonQuery() }
function Scalar($sql) { $script:cmd.CommandText = $sql; return $script:cmd.ExecuteScalar() }

# pastikan backup ada
foreach ($t in 'diag117_backup_tstok2','diag117_backup_aptrans','diag117_backup_gl') {
    $n = Scalar "SELECT COUNT(*) FROM systable WHERE table_name='$t'"
    if ([int]$n -eq 0) { Write-Host "STOP: tabel backup $t tidak ada - fix belum pernah dieksekusi?"; exit 1 }
}

# -------------------------------------------------------------------
# 1. Rollback tstok2.biaya_ekspedisi (per baris, dari snapshot paling awal)
# -------------------------------------------------------------------
foreach ($oc in $docs) {
    $t0 = Scalar "SELECT MIN(bak_time) FROM diag117_backup_tstok2 WHERE bukti_id='$oc'"
    if ($null -eq $t0 -or $t0 -is [DBNull]) { $out += "tstok2 [$oc]: tidak ada backup - SKIP"; continue }
    $cmd.CommandText = "SELECT urut, biaya_ekspedisi FROM diag117_backup_tstok2 WHERE bukti_id='$oc' AND bak_time='$($t0.ToString('yyyy-MM-dd HH:mm:ss.fff'))'"
    $rows = @()
    $r = $cmd.ExecuteReader(); while ($r.Read()) { $rows += ,@($r[0], $r[1]) }; $r.Close()
    $out += "tstok2 [$oc]: " + $rows.Count + " baris akan dikembalikan (snapshot $t0)"
    if ($DoUpdate) {
        foreach ($row in $rows) {
            Exec "UPDATE tstok2 SET biaya_ekspedisi = $($row[1]) WHERE bukti_id='$oc' AND urut=$($row[0])"
        }
        Exec "COMMIT"
        $v = Scalar "SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id='$oc'"
        $out += "  selesai. alloc kembali = $v"
    }
}

# -------------------------------------------------------------------
# 2. Rollback ap_trans dokumen FR (ttl_kotor & ttl_netto dari snapshot awal)
# -------------------------------------------------------------------
foreach ($fr in $frdocs) {
    $t0 = Scalar "SELECT MIN(bak_time) FROM diag117_backup_aptrans WHERE order_client='$fr'"
    if ($null -eq $t0 -or $t0 -is [DBNull]) { $out += "ap_trans [$fr]: tidak ada backup - SKIP"; continue }
    $k = Scalar "SELECT ttl_kotor FROM diag117_backup_aptrans WHERE order_client='$fr' AND bak_time='$($t0.ToString('yyyy-MM-dd HH:mm:ss.fff'))'"
    $n = Scalar "SELECT ttl_netto FROM diag117_backup_aptrans WHERE order_client='$fr' AND bak_time='$($t0.ToString('yyyy-MM-dd HH:mm:ss.fff'))'"
    $out += "ap_trans [$fr]: kembalikan ttl_kotor=$k ttl_netto=$n"
    if ($DoUpdate) {
        Exec "UPDATE ap_trans SET ttl_kotor=$k, ttl_netto=$n WHERE order_client='$fr'"
        Exec "COMMIT"
        $out += "  selesai."
    }
}

# -------------------------------------------------------------------
# 3. Rollback gl_journal modul EX (hapus baris sekarang, insert dari snapshot awal)
#    Snapshot diag117_backup_gl adalah full-row sehingga restore 1:1.
# -------------------------------------------------------------------
$t0 = Scalar "SELECT MIN(bak_time) FROM diag117_backup_gl"
if ($null -eq $t0 -or $t0 -is [DBNull]) {
    $out += "gl_journal: tidak ada backup - SKIP (jika fix belum -DoUpdate memang tidak ada)"
} else {
    # susun daftar kolom gl_journal secara dinamis (tanpa kolom bak_time)
    $cols = @()
    $cmd.CommandText = "SELECT c.column_name FROM systable t JOIN syscolumn c ON c.table_id=t.table_id WHERE t.table_name='gl_journal' ORDER BY c.column_id"
    $r = $cmd.ExecuteReader(); while ($r.Read()) { $cols += $r[0].ToString() }; $r.Close()
    $collist = ($cols | ForEach-Object { '"' + $_ + '"' }) -join ','
    $nBak = Scalar "SELECT COUNT(*) FROM diag117_backup_gl WHERE doc_reff IN ($all) AND bak_time='$($t0.ToString('yyyy-MM-dd HH:mm:ss.fff'))'"
    $nNow = Scalar "SELECT COUNT(*) FROM gl_journal WHERE modul_id='EX' AND doc_reff IN ($all)"
    $out += "gl_journal: baris EX sekarang=$nNow, akan diganti dgn snapshot awal=$nBak baris"
    if ($DoUpdate) {
        Exec "DELETE FROM gl_journal WHERE modul_id='EX' AND doc_reff IN ($all)"
        Exec "INSERT INTO gl_journal ($collist) SELECT $collist FROM diag117_backup_gl WHERE doc_reff IN ($all) AND bak_time='$($t0.ToString('yyyy-MM-dd HH:mm:ss.fff'))'"
        Exec "COMMIT"
        $v = Scalar "SELECT COUNT(*) FROM gl_journal WHERE modul_id='EX' AND doc_reff IN ($all)"
        $out += "  selesai. baris EX sekarang = $v"
    }
}

$conn.Close()
$out += ""
$out += "Setelah rollback: jalankan diag117_verify.ps1 untuk memastikan kondisi kembali seperti semula."
$out -join "`r`n" | Write-Host
$out + "" | Add-Content c:\BTV\debug\diag117_rollback_out.txt -Encoding UTF8
