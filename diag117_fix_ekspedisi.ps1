# diag117_fix_ekspedisi.ps1
# Koreksi alokasi biaya ekspedisi (tstok2.biaya_ekspedisi) + nilai vendor tambahan (ap_trans FR)
# untuk dokumen ekspedisi pembelian yang nilai inputnya diedit SETELAH alokasi/jurnal terbentuk.
#
# PRINSIP AMAN:
#   - TIDAK menghapus dokumen apa pun. Link pembayaran (tbyr2.bukti_id) tetap utuh.
#   - TIDAK menyentuh gl_journal secara langsung. Setelah skrip ini, jalankan menu
#     Refresh Journal -> EXP utk periode April 2026: jurnal EX & FR akan terbentuk ulang
#     dari data yang sudah benar (f_transfer_ekspedisi_new + f_transfer_freight).
#   - Backup semua baris yang disentuh ke tabel diag117_backup_* sebelum update.
#   - DEFAULT = DRY-RUN: hanya menampilkan nilai sebelum/sesudah, tidak menulis apa pun.
#     Setelah angka diverifikasi, jalankan dengan -DoUpdate.
#
# CARA PAKAI:
#   Dry-run :  powershell 32bit -File diag117_fix_ekspedisi.ps1
#   Eksekusi:  powershell 32bit -File diag117_fix_ekspedisi.ps1 -DoUpdate
#   (32bit = C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe)

param(
    [switch]$DoUpdate = $false,
    [string]$Dsn = "vsp",
    [string]$Uid = "dba",
    [string]$Pwd = "jakarta"
)

# =====================================================================
# PARAMETER NILAI TARGET - WAJIB DIKONFIRMASI AKUNTANSI SEBELUM -DoUpdate
#   main = nilai invoice vendor ekspedisi utama (tanpa PPN) yang BENAR
#   fr   = nilai invoice vendor tambahan/freight yang BENAR
#          - isi nilai lama (13328000 / 26308000) jika invoice vendor tambahan MASIH BERLAKU
#          - isi 0 jika invoice vendor tambahan memang DIBATALKAN
# Nilai main di bawah sudah terkonfirmasi: V1 dibayar lunas 15.355.658 (=14.712.724+PPN).
# =====================================================================
$targets = [ordered]@{
    '10126040500001' = @{ main = 14712724; fr = 13328000; frdoc = '1012604FR05001' }
    '10126040500002' = @{ main = 19209210; fr = 26308000; frdoc = '1012604FR05002' }
}

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=$Dsn;UID=$Uid;PWD=$Pwd")
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandTimeout = 120
$out = @()
$mode = if ($DoUpdate) { "EKSEKUSI" } else { "DRY-RUN (tidak ada perubahan)" }
$out += "================ diag117 koreksi ekspedisi - mode: $mode ================"
$out += ("waktu: " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

function Exec($sql) { $script:cmd.CommandText = $sql; [void]$script:cmd.ExecuteNonQuery() }
function Scalar($sql) { $script:cmd.CommandText = $sql; return $script:cmd.ExecuteScalar() }

# ---------------------------------------------------------------------
# 0. Siapkan tabel backup (sekali saja; aman diulang)
# ---------------------------------------------------------------------
if ($DoUpdate) {
    foreach ($pair in @(
        @('diag117_backup_tstok2',  'SELECT bukti_id, urut, stok_id, qty, hrg, netto, biaya_ekspedisi FROM tstok2 WHERE 1=0'),
        @('diag117_backup_aptrans', 'SELECT order_client, order_reff, ttl_kotor, ttl_pot, ttl_ppn, ttl_netto FROM ap_trans WHERE 1=0'),
        @('diag117_backup_gl',      'SELECT * FROM gl_journal WHERE 1=0')
    )) {
        $name = $pair[0]
        $exists = Scalar "SELECT COUNT(*) FROM systable WHERE table_name='$name'"
        if ([int]$exists -eq 0) {
            Exec ("CREATE TABLE $name AS (" + $pair[1] + ")")
            Exec "ALTER TABLE $name ADD bak_time TIMESTAMP DEFAULT CURRENT TIMESTAMP"
            $out += "backup table dibuat: $name"
        }
    }
}

foreach ($oc in $targets.Keys) {
    $t = $targets[$oc]
    $frdoc = $t.frdoc
    $allocTarget = [decimal]$t.main + [decimal]$t.fr
    $out += ""
    $out += "########## $oc (target: main=$($t.main)  fr=$($t.fr)  alloc=$allocTarget) ##########"

    # --- kondisi sekarang ---
    $base      = [decimal](Scalar "SELECT SUM(netto) FROM tstok2 WHERE bukti_id='$oc'")
    $allocNow  = [decimal](Scalar "SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id='$oc'")
    $apMainNow = [decimal](Scalar "SELECT ttl_kotor FROM ap_trans WHERE order_client='$oc'")
    $apFrNow   = [decimal](Scalar "SELECT ttl_netto FROM ap_trans WHERE order_client='$frdoc'")
    $glExNow   = [decimal](Scalar "SELECT ISNULL(SUM(debet),0) FROM gl_journal WHERE modul_id='EX' AND doc_reff='$oc' AND account_id LIKE '102%'")
    $glFrNow   = [decimal](Scalar "SELECT ISNULL(SUM(debet),0) FROM gl_journal WHERE modul_id='EX' AND doc_reff='$frdoc'")
    $out += "  SEKARANG: alloc_tstok2=$allocNow  ap_main=$apMainNow  ap_fr=$apFrNow  glEX(persediaan)=$glExNow  glFR=$glFrNow  base_netto=$base"

    if ($base -le 0) { $out += "  SKIP: base netto <= 0 ?!"; continue }
    $kNew = $allocTarget / $base
    $out += ("  k baru = {0} (k lama = {1})" -f $kNew, ($allocNow/$base))

    # --- preview alokasi baru per baris (jumlah) ---
    $newAlloc = [decimal](Scalar "SELECT SUM(ROUND(hrg * $kNew, 2) * qty) FROM tstok2 WHERE bukti_id='$oc'")
    $resid = $newAlloc - $allocTarget
    $adjUrut = Scalar "SELECT FIRST urut FROM tstok2 WHERE bukti_id='$oc' AND qty=1 ORDER BY urut"
    if ($null -ne $adjUrut -and $adjUrut -isnot [DBNull] -and [Math]::Abs($resid) -gt 0) {
        $out += "  SESUDAH (hitung): alloc=$newAlloc, sisa pembulatan $resid akan ditampung ke baris urut=$adjUrut (qty=1) -> total PERSIS $allocTarget"
        $out += "  Jurnal EX yg akan dibentuk refresh: Dr Persediaan = $($t.main).00 ; Cr Hutang Ekspedisi = $($t.main) ; FR = $($t.fr)  (jurnal balance penuh, tanpa selisih sen)"
    } else {
        $adjUrut = $null
        $out += "  SESUDAH (hitung): alloc_tstok2=$newAlloc (selisih thd target $allocTarget = $resid - sen pembulatan per baris)"
        $out += "  Jurnal EX yg akan dibentuk refresh: Dr Persediaan ~$($newAlloc - $t.fr) ; Cr Hutang Ekspedisi ~$([Math]::Round($newAlloc - $t.fr)) ; FR = $($t.fr)"
    }

    if ($DoUpdate) {
        # 1. backup
        Exec "INSERT INTO diag117_backup_tstok2 (bukti_id,urut,stok_id,qty,hrg,netto,biaya_ekspedisi) SELECT bukti_id,urut,stok_id,qty,hrg,netto,biaya_ekspedisi FROM tstok2 WHERE bukti_id='$oc'"
        Exec "INSERT INTO diag117_backup_aptrans (order_client,order_reff,ttl_kotor,ttl_pot,ttl_ppn,ttl_netto) SELECT order_client,order_reff,ttl_kotor,ttl_pot,ttl_ppn,ttl_netto FROM ap_trans WHERE order_client IN ('$oc','$frdoc')"
        Exec "INSERT INTO diag117_backup_gl SELECT g.*, CURRENT TIMESTAMP FROM gl_journal g WHERE g.modul_id='EX' AND g.doc_reff IN ('$oc','$frdoc')"
        Exec "COMMIT"
        $out += "  backup OK (tstok2, ap_trans, gl_journal)"

        # 2. skala ulang alokasi per baris (pola sama dgn sistem: k seragam, bulat 2 desimal)
        Exec "UPDATE tstok2 SET biaya_ekspedisi = ROUND(hrg * $kNew, 2) WHERE bukti_id='$oc'"
        Exec "COMMIT"
        $out += "  tstok2.biaya_ekspedisi di-update"

        # 2b. tampung sisa pembulatan ke satu baris qty=1 agar total alokasi PERSIS = target
        #     (membuat jurnal hasil refresh balance penuh, tanpa selisih sen spt jurnal lama)
        $residNow = [decimal](Scalar "SELECT SUM(biaya_ekspedisi*qty) - $allocTarget FROM tstok2 WHERE bukti_id='$oc'")
        if ([Math]::Abs($residNow) -gt 0 -and $null -ne $adjUrut) {
            Exec "UPDATE tstok2 SET biaya_ekspedisi = biaya_ekspedisi - ($residNow) WHERE bukti_id='$oc' AND urut=$adjUrut"
            Exec "COMMIT"
            $out += "  sisa pembulatan $residNow ditampung ke baris urut=$adjUrut"
        }

        # 3. pulihkan nilai vendor tambahan (FR) di ap_trans sesuai target
        Exec "UPDATE ap_trans SET ttl_kotor = $($t.fr), ttl_netto = $($t.fr) WHERE order_client='$frdoc'"
        Exec "COMMIT"
        $out += "  ap_trans FR ($frdoc) di-set ke $($t.fr)"

        # 4. verifikasi
        $v1 = [decimal](Scalar "SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id='$oc'")
        $v2 = [decimal](Scalar "SELECT ttl_netto FROM ap_trans WHERE order_client='$frdoc'")
        $out += "  VERIFIKASI: alloc baru=$v1 (target $allocTarget) ; ap_fr=$v2"
    }
}

$conn.Close()
$out += ""
$out += "LANGKAH SELANJUTNYA setelah -DoUpdate sukses:"
$out += "  1. Buka menu Refresh Journal -> tombol EXP, periode 01-04-2026 s/d 30-04-2026."
$out += "  2. Cek ulang jurnal kedua dokumen (query pembanding: diag116b.ps1)."
$out += "  3. Jalankan proses refresh stok/HPP rutin agar HPP rata-rata ikut menyerap nilai baru."
$out | Set-Content c:\BTV\debug\diag117_fix_out.txt -Encoding UTF8
$out -join "`r`n" | Write-Host
