# diag117_verify.ps1
# Verifikasi kondisi data ekspedisi April 2026 - jalankan SEBELUM dan SESUDAH perbaikan.
# Read-only: tidak mengubah apa pun. Output ke layar + diag117_verify_out.txt (append, bertanda waktu).
param(
    [string]$Dsn = "vsp",
    [string]$Uid = "dba",
    [string]$Pwd = "jakarta"
)

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=$Dsn;UID=$Uid;PWD=$Pwd")
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandTimeout = 120
$out = @()
$out += "================ diag117 VERIFIKASI - " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " ================"

function Scalar($sql) { $script:cmd.CommandText = $sql; return $script:cmd.ExecuteScalar() }

$docs = @(
    @{ main='10126040500001'; fr='1012604FR05001'; target_main=14712724; target_fr=13328000 },
    @{ main='10126040500002'; fr='1012604FR05002'; target_main=19209210; target_fr=26308000 },
    @{ main='10126040500003'; fr='1012604FR05003'; target_main=67475908; target_fr=9967200 }   # pembanding (sehat)
)

foreach ($d in $docs) {
    $oc = $d.main; $fr = $d.fr
    $out += ""
    $out += "########## $oc  (pasangan FR: $fr) ##########"

    $alloc   = Scalar "SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id='$oc'"
    $apK     = Scalar "SELECT ttl_kotor FROM ap_trans WHERE order_client='$oc'"
    $apPpn   = Scalar "SELECT ttl_ppn  FROM ap_trans WHERE order_client='$oc'"
    $apN     = Scalar "SELECT ttl_netto FROM ap_trans WHERE order_client='$oc'"
    $apFr    = Scalar "SELECT ttl_netto FROM ap_trans WHERE order_client='$fr'"
    $glDr    = Scalar "SELECT ISNULL(SUM(debet),0)  FROM gl_journal WHERE modul_id='EX' AND doc_reff='$oc'"
    $glCr    = Scalar "SELECT ISNULL(SUM(kredit),0) FROM gl_journal WHERE modul_id='EX' AND doc_reff='$oc'"
    $glPers  = Scalar "SELECT ISNULL(SUM(debet),0)  FROM gl_journal WHERE modul_id='EX' AND doc_reff='$oc' AND account_id LIKE '102%'"
    $glHut   = Scalar "SELECT ISNULL(SUM(kredit),0) FROM gl_journal WHERE modul_id='EX' AND doc_reff='$oc' AND account_id LIKE '226%'"
    $glFrDr  = Scalar "SELECT ISNULL(SUM(debet),0)  FROM gl_journal WHERE modul_id='EX' AND doc_reff='$fr'"
    $glFrCr  = Scalar "SELECT ISNULL(SUM(kredit),0) FROM gl_journal WHERE modul_id='EX' AND doc_reff='$fr'"

    $out += "  INPUT ap_trans  : kotor=$apK  ppn=$apPpn  netto=$apN   | vendor tambahan (FR)=$apFr"
    $out += "  ALOKASI tstok2  : $alloc   (target = main+fr = $($d.target_main + $d.target_fr))"
    $out += "  JURNAL EX utama : totalDr=$glDr totalCr=$glCr | Dr persediaan(102%)=$glPers | Cr hutang(226%)=$glHut"
    $out += "  JURNAL FR       : Dr=$glFrDr Cr=$glFrCr"

    # status checks
    $ok1 = [Math]::Abs([decimal]$glHut - [decimal]$apN) -lt 1
    $ok2 = [Math]::Abs([decimal]$glPers - [decimal]$d.target_main) -lt 1
    $ok3 = [Math]::Abs([decimal]$glDr - [decimal]$glCr) -lt 1
    $out += "  CEK: total Cr hutang(226%) = netto input? " + $(if($ok1){"OK"}else{"BELUM ($glHut <> $apN)"})
    $out += "  CEK: Dr persediaan = nilai invoice utama ($($d.target_main))? " + $(if($ok2){"OK"}else{"BELUM"})
    $out += "  CEK: jurnal balance (Dr=Cr)? " + $(if($ok3){"OK"}else{"TIDAK BALANCE!"})

    # pembayaran terkait (link harus tetap utuh)
    $cmd.CommandText = "SELECT t2.voucher, t1.voucher_manual, t1.tgl, t2.nilai_bayar_idr FROM tbyr2 t2 JOIN tbyr1 t1 ON t1.voucher=t2.voucher WHERE t2.bukti_id IN ('$oc','$fr')"
    $r = $cmd.ExecuteReader(); $n = 0
    while ($r.Read()) { $n++; $out += "  PEMBAYARAN: v=[$($r[0])] vm=[$($r[1])] tgl=$($r[2]) idr=$($r[3])" }
    $r.Close()
    if ($n -eq 0) { $out += "  PEMBAYARAN: belum ada" }
}

$conn.Close()
$out -join "`r`n" | Write-Host
$out + "" | Add-Content c:\BTV\debug\diag117_verify_out.txt -Encoding UTF8
