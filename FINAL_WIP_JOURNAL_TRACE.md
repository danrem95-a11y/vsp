# Trace Jurnal WIP-Out + Solusi WIP-as-Location + Costing Rule
Evidence-based, prod 103.233.89.43:2638. Sesuai statement Accounting Pak Wira (WIP-Out = fisik pindah lokasi, JANGAN write-off).

## 1. BUKTI: jurnal WIP-Out sudah benar (Dr 102-020 / Cr TR-NR-TB)
GL 102-020 movement 2025 per lawan-akun:
| Lawan | Dr 102-020 (WIP-Out) | Cr 102-020 (WIP-In) | Net |
|---|---:|---:|---:|
| 102-001 TR | 52.283.652.175 | 51.991.646.966 | +291.005.209 |
| 102-006 TB | 901.182.839 | 901.182.839 | 0 |
| 102-003 NR | 314.000.000 | 314.000.000 | 0 |
| 102-018 | 182.065.300 | 182.065.300 | 0 |

Saldo 102-020: opening 2025 1.542.048.226 + net 2025 325.642.790 = **1.867.691.016** (closing 2025).

## 2. REKONSILIASI 3-ARAH (31-12-2025) — konsisten
| Sumber | Nilai | Ket |
|---|---:|---|
| **Outstanding fisik** (WIP-Out '88' belum WIP-In & belum jual, at HPP) | **1.799.966.016** | TR 23 serial 1.761.561.603 + TB 76 serial 38.404.412 |
| **Jurnal net → 102-020** | **1.867.691.016** | selisih ~67 jt = 102-011 |
| **Stok WIP** | **0** | belum ada representasi stok |

→ **WIP riil = ±1,8 M, sudah terjurnal & tersaldo di 102-020; hanya STOK-nya belum ada.**

## 3. Gap TR 10,11 M BUKAN WIP (bukti transaksi)
Breakdown lonjakan saldo 1-Des-2025 → 1-Jan-2026 (102-001):
| Model | Nilai Des | Nilai Jan | Lonjakan | Penyebab |
|---|---:|---:|---:|---|
| TR.038A | 3.446.717.699 | 9.637.819.584 | **+6.191.101.885** | '02' 12 unit @Rp14.593 (≈0) + '05' 12 unit @243 jt, **bukti sama-tgl** |
| TR.039A | 0 | 5.280.171.127 | **+5.280.171.127** | '02' 19 unit @≈0 + '05' 19 unit @full |
| lainnya | | | −1,36 M net | gerakan normal |

'02' = entry qty di harga ≈ nol, berpasangan tanggal & bukti berurutan dengan pembelian '05' harga penuh → **double-posting / entry harga-nol** yang digelembungkan moving-average. **BUKAN WIP, BUKAN barang hilang.** → OPTION C: koreksi transaksi spesifik (audit-safe), bukan write-down massal.

## 4. SOLUSI (sesuai aturan Accounting)

### BAGIAN A — WIP jadi lokasi/gudang stok (102-020) — AMAN
Reklas outstanding WIP-Out (1,8 M) TR/TB → item stok WIP 102-020, **preserve serial + HPP WIP-Out**:
- Buat produk WIP per model (group_product → persediaan 102-020), qty = outstanding, nilai = HPP WIP-Out (BEKU).
- Serial tetap terlacak via transaksi '88' (evap) yang sudah ada — tak diubah.
- sinv 102-020 = 1,8 M = ledger 102-020 → **102-020 balance & muncul sebagai persediaan WIP.**
- **Tak kurangi stok, tak write-off, jurnal tak berubah** (ledger 102-020 sudah ada; ini menambah SISI STOK agar cocok).
- Preview: `wip_migration_preview.sql`.

### BAGIAN B — Costing ikut asal inventory (WIP-Out-immutable HPP) — SUDAH DIBANGUN
Aturan: jual dari WIP → HPP = HPP WIP-Out (BEKU); jual dari stok normal → HPP average.
Ini **persis engine redesign** yang sudah dikode: `n_cst_closing_stock.sru` (C1 freeze WIP-Out hpp, C2 average NON-WIP only via filter evap='', C3 WIP sale = MAX '88' beku) + modern R6/R7 OFF. Test: `costing_test_cases.sql` (Case 1 & 2).

### BAGIAN C — Gap 10,11 M (TR.038A/039A '02') — koreksi transaksi spesifik (hybrid)
Bukan WIP, bukan write-down massal. Telusuri & koreksi transaksi '02' harga-nol yang double dengan '05'. Perlu: konfirmasi apakah '02' = re-entry unit yang sama dengan '05' (double) atau unit terpisah. **Jangan sentuh sampai transaksi penyebab dikonfirmasi** (sesuai instruksi Bapak).

## 5. Target & validasi
- **A.** Setelah BAGIAN A: sinv 102-020 = ledger 102-020 (1,8 M) → WIP terlihat sebagai stok. ✅
- **B.** Costing: Case 1 (WIP sale → HPP WIP-Out) & Case 2 (normal → average) PASS.
- **C.** TR = ledger tercapai setelah BAGIAN C (koreksi '02') — BUKAN dengan menurunkan stok, tapi mengoreksi transaksi harga-nol yang terbukti salah.
- Mutasi Jan-Feb TIDAK berubah (semua koreksi di opening/reklas, bukan gerakan).

## 6. Yang perlu Bapak putuskan (bukan konfirmasi teknis)
BAGIAN A & B aman & siap. **BAGIAN C** butuh Bapak konfirmasi status transaksi '02' TR.038A/039A (apakah double-posting unit yang sama dengan '05', atau unit fisik terpisah). Itu penentu apakah 10,11 M dikoreksi (double) atau diakui (unit real → recognize di GL). **Saya tidak melakukan apa pun ke 10,11 M sampai itu jelas.**
