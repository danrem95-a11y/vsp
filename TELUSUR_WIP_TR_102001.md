# Telusur WIP TR (102-001) — hasil jurnal + worksheet stock-opname

Read-only dari DB prod (vspnew) 2026-07-31. Menjawab permintaan Pak Wira: telusuri 91 unit fisik.

## 1. Fakta jurnal (per 31-12-2025)
- **102-020 = Rp 1.867.691.015,56** — cocok ke rupiah dengan WIP-Out '88' yang **terjurnal** (TR 1,76 M ↔ 102-020 1,76 M). Loop WIP yang tercatat SEHAT.
- WIP-Out '88' TR yang outstanding di jurnal = **35 serial (1,76 M)**; 12 di antaranya **hpp=0** (bug cost-loss EVAP). Trace: `TR_wipout_serial_trace.csv`.
- Jadi gap **10,11 M BUKAN** dari WIP-Out yang terjurnal — melainkan unit **fisik keluar untuk instalasi yang TIDAK pernah dibukukan sebagai WIP-Out** (konfirmasi Pak Wira: unit real di lokasi).

## 2. Kenapa tidak bisa "serial by serial" murni
TR **tidak diserialkan di stok** — tiap `stok_id` = satu MODEL dengan qty banyak unit. Serial hanya muncul di transaksi WIP-Out (`evap`). Unit yang keluar tanpa WIP-Out **tak punya jejak serial** di sistem; jejaknya = **qty model lebih besar dari fisik**. Maka telusur yang benar = **hitung fisik per MODEL**, selisih (sistem − fisik) = unit di lokasi.

## 3. Struktur nilai (temuan penting)
Nilai 23,11 M menumpuk di segelintir model "-A" (EVAP/COND). Model dasar (tanpa A) ber-nilai 0. **Cukup hitung ~13 model bernilai; 6 model ini ≈ 21 M (91%):**

| Model | Deskripsi | Qty sistem | HPP/unit | Nilai sistem |
|---|---|---:|---:|---:|
| TR.038A | T-1200 R EVAP/COND | 39 | 247.123.579 | 9.637.819.584 |
| TR.039A | T-1080 PRO EVAP/COND | 25 | 211.206.845 | 5.280.171.127 |
| TR.040A | T-1280 E EVAP/COND | 9 | 201.915.420 | 1.817.238.782 |
| TR.1002A | SV-400 EVAP/COND | 51 | 34.649.470 | 1.767.122.972 |
| TR.1003A | SV-600 EVAP/COND | 44 | 38.464.452 | 1.692.435.909 |
| TR.910A | RV-300 12V EVAP/COND | 34 | 27.165.190 | 923.616.446 |
| (lainnya, 7 model) | | | | ± 1,99 M |
| **TOTAL** | | | | **23.110.313.890** |

Catatan: **62 dari 99 model ber-qty ≤ 0** (distorsi moving-average) — nilai 0, bisa diabaikan untuk hitung fisik.

## 4. Langkah Pak Wira (worksheet)
1. Buka **`TR_stok_opname_worksheet.csv`** (99 baris; fokus ~13 baris nilai > 0).
2. Isi kolom **`qty_fisik_ISI_MANUAL`** dari hitung fisik gudang.
3. `selisih_unit = qty_sistem − qty_fisik` = **unit yang fisik keluar untuk instalasi**.
4. Kirim balik → saya hitung **nilai WIP-Out yang harus dibukukan** per model = `selisih_unit × HPP/unit`, jadi dasar **Opsi 4** (pindahkan TR → 102-020 WIP) atau **Opsi 3** (turunkan sinv TR ke Ledger).

## 5. Konsekuensi akuntansi (yang Pak Wira konfirmasi: unit REAL)
Jika 91 unit real & fisik keluar tapi belum dibukukan WIP-Out:
- Nilainya kini menumpuk di **sinv TR (102-001)** sebagai stok, padahal fisik tak di gudang.
- Seharusnya pindah ke **102-020 (WIP)** lewat WIP-Out (Dr 102-020 / Cr 102-001) → total aset persediaan tetap, hanya reklas TR → WIP.
- Setelah reklas: sinv TR turun ≈ Ledger 102-001, dan 102-020 naik jadi ± 11,86 M (sesuai angka Pak Wira). **Ini yang membuat Mutasi Stok TR = Ledger DAN WIP tampil benar.**
