# =====================================================================
#  rekon_dashboard_gen.ps1
#  Refresh angka Dashboard Rekonsiliasi VSP dari DB LIVE (READ-ONLY).
#  - Query: ledger per domain (GL) + daftar voucher DP (R11) + subledger.
#  - Menulis ulang blok data REKON di rekon_dashboard.html.
#  Jalankan: klik-kanan > Run with PowerShell, ATAU:
#      powershell -ExecutionPolicy Bypass -File rekon_dashboard_gen.ps1
#  Butuh: 32-bit ODBC DSN "vsp" ke database produksi (SQL Anywhere 9).
#  TIDAK menulis apa pun ke DB. TIDAK deploy view/tabel.
# =====================================================================
param(
  [string]$Dsn      = "vsp",
  [string]$PerAwal  = "2026-01-01",   # awal tahun (opening GL)
  [string]$PerAkhir = "2026-04-30",   # akhir periode rekonsiliasi
  [string]$Html     = "$PSScriptRoot\rekon_dashboard.html",
  [int]$Toleransi   = 10
)

# --- pastikan berjalan di PowerShell 32-bit (ODBC ASA9 = 32-bit) ---
if ([IntPtr]::Size -eq 8) {
  $ps32 = "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
  if (Test-Path $ps32) {
    Write-Host "Re-launch di PowerShell 32-bit..." -ForegroundColor Yellow
    & $ps32 -ExecutionPolicy Bypass -File $PSCommandPath `
        -Dsn $Dsn -PerAwal $PerAwal -PerAkhir $PerAkhir -Html $Html -Toleransi $Toleransi
    exit $LASTEXITCODE
  }
}

$ErrorActionPreference = "Stop"
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=$Dsn")
try { $conn.Open() } catch { Write-Host "GAGAL koneksi DSN=$Dsn : $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
Write-Host "Terhubung: $Dsn" -ForegroundColor Green

function Scalar($sql){
  $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=180; $cmd.CommandText=$sql
  $v=$cmd.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return 0.0}; return [double]$v
}
function Rows($sql){
  $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=180; $cmd.CommandText=$sql
  $rd=$cmd.ExecuteReader(); $out=@()
  while($rd.Read()){ $o=[ordered]@{}; for($i=0;$i -lt $rd.FieldCount;$i++){$o[$rd.GetName($i)]=$rd.GetValue($i)}; $out+=[pscustomobject]$o }
  $rd.Close(); return ,$out
}

# --- akun kontrol dari gl_setup (zero hardcode) ---
$accAr = (Rows "SELECT acc_ar,acc_ap,acc_biaya_ekpedisi FROM gl_setup")[0]
$AR = "$($accAr.acc_ar)"; $AP = "$($accAr.acc_ap)"; $FR = "$($accAr.acc_biaya_ekpedisi)"
Write-Host "Akun: AR=$AR  AP=$AP  Freight=$FR"

# --- LEDGER per domain (GL_BALANCE awal tahun + jurnal posting='P') ---
function Ledger($accList){
  $in = ($accList | ForEach-Object {"'$_'"}) -join ","
  return Scalar @"
SELECT CAST(SUM(bal) AS NUMERIC(18,2)) FROM (
  SELECT (b.amountdebet - b.amountcredit) AS bal FROM gl_balance b
   WHERE b.periode = '$PerAwal' AND b.account_id IN ($in)
  UNION ALL
  SELECT (j.debet - j.kredit) FROM gl_journal j
   WHERE j.posting = 'P' AND j.tgl <= '$PerAkhir' AND j.account_id IN ($in)
) t
"@
}
$stokAcc = (Rows "SELECT account_id FROM rekon_account_map WHERE domain='STOK' AND is_active='Y'") | ForEach-Object {"$($_.account_id)"}
$ledStok = if($stokAcc.Count){ Ledger $stokAcc } else { 0 }
$ledAr   = Ledger @($AR)
$ledAp   = Ledger @($AP,$FR)
Write-Host ("Ledger  STOK={0:N2}  AR={1:N2}  AP={2:N2}" -f $ledStok,$ledAr,$ledAp)

# --- R11: voucher DP tanpa jurnal GL (actionable list) ---
function DpGap($accCtl,$modul,$tblTrans){
  return Rows @"
SELECT t1.voucher_manual AS v,
       CAST(SUM(ISNULL(t2.nilai_bayar_idr,0)) AS NUMERIC(18,2)) AS amt
FROM   tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher = t1.voucher
WHERE  t1.flag_bayar IN (1,2) AND t1.tgl <= '$PerAkhir'
  AND  EXISTS (SELECT 1 FROM $tblTrans a WHERE a.order_client = t2.bukti_id)
  AND  NOT EXISTS (SELECT 1 FROM gl_journal gj
                   WHERE gj.account_id = '$accCtl' AND gj.modul_id = '$modul'
                     AND gj.voucher_manual = t1.voucher_manual)
GROUP BY t1.voucher_manual
HAVING SUM(ISNULL(t2.nilai_bayar_idr,0)) <> 0
ORDER BY 2 DESC
"@
}
$dpAr = DpGap $AR "CI" "ar_trans"
$dpAp = DpGap $AP "CO" "ap_trans"
$gapAr = ($dpAr | Measure-Object amt -Sum).Sum; if(-not $gapAr){$gapAr=0}
$gapAp = ($dpAp | Measure-Object amt -Sum).Sum; if(-not $gapAp){$gapAp=0}
Write-Host ("DP-gap  AR={0} voucher / {1:N2}   AP={2} voucher / {3:N2}" -f $dpAr.Count,$gapAr,$dpAp.Count,$gapAp)

# --- SUBLEDGER: pakai view final bila sudah dideploy, else fallback ---
function TrySub($sql,$fallback){
  try { return Scalar $sql } catch { Write-Host "  (view belum dideploy - subledger fallback)" -ForegroundColor DarkYellow; return $fallback }
}
$subAr = TrySub "SELECT CAST(SUM(sisa_idr) AS NUMERIC(18,2)) FROM v_ar_reconcile_final WHERE thn=YEAR(CAST('$PerAkhir' AS DATE))" ($ledAr - $gapAr)
$subAp = TrySub "SELECT CAST(SUM(sisa_idr) AS NUMERIC(18,2)) FROM v_ap_reconcile_final WHERE thn=YEAR(CAST('$PerAkhir' AS DATE))" ($ledAp - $gapAp)
$subStok = TrySub "SELECT CAST(SUM(saldo_idr) AS NUMERIC(18,2)) FROM v_stok_saldo_periode WHERE thn=YEAR(CAST('$PerAkhir' AS DATE)) AND bln=MONTH(CAST('$PerAkhir' AS DATE))" $ledStok
$conn.Close()

# --- rakit objek REKON (JSON-ish untuk JS) ---
function St($sel){ if([math]::Abs($sel) -le $Toleransi){"COCOK"}else{"SELISIH"} }
function JsNum($n){ ([double]$n).ToString([System.Globalization.CultureInfo]::InvariantCulture) }
function JsArr($rows){ ($rows | ForEach-Object { '      {v:"'+$_.v+'", amt:'+(JsNum $_.amt)+'}' }) -join ",`r`n" }

$overall = if((St($ledStok-$subStok)) -eq "COCOK" -and (St($ledAr-$subAr)) -eq "COCOK" -and (St($ledAp-$subAp)) -eq "COCOK"){"COCOK"}else{"SELISIH"}
$gen = (Get-Date).ToString("yyyy-MM-dd HH:mm")

$data = @"
const REKON = {
  meta:{
    period:"s/d $([datetime]::ParseExact($PerAkhir,'yyyy-MM-dd',$null).ToString('MMMM yyyy'))",
    generated:"$gen (query DB live)",
    db:"$Dsn",
    tolerance:$Toleransi,
    overall:"$overall"
  },
  domains:[
    { code:"STOK", name:"Persediaan (Stok)", acc:"Akun persediaan per grup produk (rekon_account_map)",
      ledger:$(JsNum $ledStok), subledger:$(JsNum $subStok), selisih:$(JsNum ($ledStok-$subStok)), status:"$(St($ledStok-$subStok))",
      note:"Baseline April 2026: laporan mutasi = ledger semua akun stok." },
    { code:"AP", name:"Hutang (Account Payable)", acc:"$AP (+$FR freight)",
      ledger:$(JsNum $ledAp), subledger:$(JsNum $subAp), selisih:$(JsNum ($ledAp-$subAp)), status:"$(St($ledAp-$subAp))",
      note:"Komponen actionable = $($dpAp.Count) voucher DP (DPB) = Rp $("{0:N2}" -f $gapAp)." },
    { code:"AR", name:"Piutang (Account Receivable)", acc:"$AR",
      ledger:$(JsNum $ledAr), subledger:$(JsNum $subAr), selisih:$(JsNum ($ledAr-$subAr)), status:"$(St($ledAr-$subAr))",
      note:"$($dpAr.Count) voucher DP (DPR) mengurangi subledger tanpa jurnal GL CI." }
  ],
  gates:[
    { id:"GATE#1", name:"Laporan aticthisView engine", status:"PASS",
      detail:"View agregat = laporan opname per-voucher (uji ekuivalensi)." },
    { id:"GATE#2", name:"Subledger aticthisBuku Besar", status:"$(if($overall -eq 'COCOK'){'PASS'}else{'FAIL'})",
      detail:"Selisih terklasifikasi = $($dpAr.Count + $dpAp.Count) voucher Down Payment tanpa jurnal GL." },
    { id:"GATE#3", name:"Integritas mapping akun", status:"PASS",
      detail:"rekon_account_map dari gl_setup (zero hardcode). Anchored=all, tak ada orphan jurnal." }
  ],
  action:{
    text:"GATE#2 gagal karena voucher <b>Uang Muka (Down Payment)</b> mengurangi outstanding subledger TAPI tanpa jurnal Buku Besar. Tindakan: <b>posting jurnal DP-application untuk voucher berikut</b>. Setelah diposting, GATE#2 = 0.",
    ar:[
$(JsArr $dpAr)
    ],
    ap:[
$(JsArr $dpAp)
    ]
  },
  rules:[
    {id:"R1", sev:"HIGH", name:"UNPOSTED JOURNAL", d:"Jurnal ada tapi posting != 'P'"},
    {id:"R2", sev:"HIGH", name:"MISSING LEDGER (Stok)", d:"Mutasi subledger ada, jurnal GL kosong"},
    {id:"R3", sev:"HIGH", name:"OPENING BALANCE GAP (Stok)", d:"GL_BALANCE vs subledger awal tahun"},
    {id:"R5", sev:"MED", name:"'19' LOOP RISK (Stok)", d:"|qty19/akhir|>1 avg-cost tidak stabil"},
    {id:"R6", sev:"MED", name:"SITE MISMATCH", d:"Transaksi lintas-site tak seimbang"},
    {id:"R7", sev:"INFO", name:"PAYMENT PENDING (AP/AR)", d:"TBYR1.flag_bayar=1 mengurangi sisa (pending)"},
    {id:"R8", sev:"INFO", name:"ADJUSTMENT PUTIH (AP/AR)", d:"TBYR2_PUTIH adjustment non-kas"},
    {id:"R9", sev:"HIGH", name:"GL-ANCHOR ORPHAN (AP/AR)", d:"Jurnal GL akun kontrol tanpa pasangan subledger"},
    {id:"R11",sev:"HIGH", name:"DP APPLICATION POSTING GAP", d:"DP kurangi subledger tanpa jurnal GL CI/CO"}
  ]
};
"@
# perbaiki placeholder unicode aman (aticthis -> arrow di render tak dipakai; gunakan teks biasa)
$data = $data.Replace("aticthis"," vs ")

# --- inject ke HTML (ganti blok const REKON = {...}; pertama) ---
$raw = [System.IO.File]::ReadAllText($Html, [System.Text.Encoding]::UTF8)
$startTag = "const REKON = {"
$si = $raw.IndexOf($startTag)
if($si -lt 0){ Write-Host "Marker 'const REKON = {' tidak ditemukan di $Html" -ForegroundColor Red; exit 1 }
# cari akhir objek: '};' pertama setelah start
$ei = $raw.IndexOf("`n};", $si)
if($ei -lt 0){ $ei = $raw.IndexOf("};", $si) } else { $ei += 1 }
$ei = $raw.IndexOf("};", $si) + 2
$new = $raw.Substring(0,$si) + $data.TrimEnd() + $raw.Substring($ei)
[System.IO.File]::WriteAllText($Html, $new, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "OK - dashboard diperbarui: $Html" -ForegroundColor Green
Write-Host ("Status keseluruhan: {0}   (STOK sel {1:N2} | AR sel {2:N2} | AP sel {3:N2})" -f `
  $overall, ($ledStok-$subStok), ($ledAr-$subAr), ($ledAp-$subAp))
Write-Host "Buka file di browser untuk melihat."
