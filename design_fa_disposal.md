# Desain: Disposal / Pelepasan Aktiva Tetap (modul FA, site 101)

Requirement bisnis: aset yang **habis nilai buku DAN rusak/dijual/tidak dipakai** dikeluarkan dari
daftar aktif (disposal/write-off), **tanpa** menghapus histori pembelian & penyusutan (audit).
Opening 2026 = Excel Daftar Aktiva; histori pra-2026 tidak dimigrasi.

## 1. Terminologi menu (rekomendasi)
- **Transaksi → "Disposal Aktiva Tetap"** (window `w_fa_disposal`). 
  - JANGAN pakai "Penghapusan Aset" (menyesatkan = delete). "Aset Keluar" dipakai untuk LAPORAN.
- **Laporan → "Daftar Aset Keluar / Arsip Aktiva"** (`dw_rpt_fa_disposal`).
- Opsional: **"Batal Disposal"** (reversal sebelum closing).

## 2. Status aset — pakai kolom `FA_ASSET.status` yang sudah ada (A/F/D/X), perjelas:
| status | Arti | Muncul di daftar aktif? |
|---|---|---|
| **A** | Aktif — masih disusutkan, NBV > 0  (kasus a) | ya |
| **F** | Habis susut — NBV = 0 tapi masih dimiliki/dipakai (kasus b) | ya |
| **D** | Keluar / Disposal (kasus c) | tidak (hanya di Arsip) |
| X | Non-aktif sementara (opsional) | tidak |

Sub-jenis disposal disimpan di `FA_DISPOSAL.disposal_type`: **RUSAK / DIJUAL / TDKPAKAI / HIBAH / LAINNYA**.

- Daftar AKTIF  = `status IN ('A','F')`
- Daftar KELUAR = `status = 'D'`
- (a) vs (b) dibedakan dari NBV: `book_value > 0` = "Aktif", `= 0` = "Habis Susut (Dipakai)".
- 'F' di-set otomatis oleh engine saat NBV mencapai 0 (atau derive dari NBV di laporan).

## 3. Struktur tabel (audit-safe, TANPA hard delete)
- `FA_ASSET`         : TETAP. Hanya UPDATE `status='D'`, `disposal_date`, `remarks`. Cost/akum/umur tak diubah.
- `FA_DEPRECIATION`  : TETAP. Histori penyusutan TIDAK dihapus.
- `FA_DISPOSAL` (BARU) : header pelepasan (audit trail):
```sql
CREATE TABLE FA_DISPOSAL (
  site_id          varchar(4)   NOT NULL,
  disposal_no      varchar(20)  NOT NULL,      -- DSP101202607-0001
  asset_code       varchar(20)  NOT NULL,
  disposal_date    date         NOT NULL,
  disposal_type    varchar(10)  NOT NULL,      -- RUSAK/DIJUAL/TDKPAKAI/HIBAH/LAINNYA
  acquisition_cost numeric(18,2),
  accum_dep        numeric(18,2),              -- akumulasi s/d tgl disposal
  book_value       numeric(18,2),              -- NBV saat disposal
  proceeds         numeric(18,2) DEFAULT 0,    -- hasil jual (0 bila rusak/dibuang)
  gain_loss        numeric(18,2),              -- proceeds - book_value
  journal_no       varchar(15),                -- voucher GL disposal (modul FA)
  reason           varchar(200),
  disposed_by      varchar(30),
  created_date     timestamp DEFAULT CURRENT TIMESTAMP,
  PRIMARY KEY (site_id, disposal_no)
);
CREATE INDEX ix_fa_disposal_asset ON FA_DISPOSAL(site_id, asset_code);
```
History pembelian pra-2026 memang tidak ada di modul (opening dari Excel), jadi cost+akum = OPENING
BALANCE di neraca (dari sistem lama). Disposal mengeluarkannya lewat jurnal (lihat #4).

## 4. Perlakuan jurnal akuntansi (posting modul FA, voucher DSP...)
Prinsip: keluarkan cost + akumulasi dari neraca, catat kas & laba/rugi.
```
Dr  Akumulasi Penyusutan (accum_dep_account)   = accum_dep saat disposal
Dr  Kas/Bank (bila DIJUAL)                      = proceeds
Dr  Rugi Pelepasan Aktiva   (bila book_value > proceeds)   } salah satu
Cr  Laba Pelepasan Aktiva   (bila proceeds > book_value)   } (selisih)
Cr  Aktiva Tetap (asset_account)                = acquisition_cost
```
Contoh A — habis susut (NBV=0), rusak, tanpa hasil:
`Dr Akum Peny = cost ; Cr Aktiva = cost` → net 0, tanpa L/R. Cost+akum keluar dari neraca.

Contoh B — NBV 10jt, dijual 15jt:
`Dr Akum Peny (cost-10jt) ; Dr Kas 15jt ; Cr Aktiva (cost) ; Cr Laba Pelepasan 5jt`.

Contoh C — NBV 10jt, dibuang (proceeds 0):
`Dr Akum Peny (cost-10jt) ; Dr Rugi Pelepasan 10jt ; Cr Aktiva (cost)`.

Butuh 2 akun COA baru (bila belum ada): **Laba Pelepasan Aktiva** & **Rugi Pelepasan Aktiva** (atau 1 akun L/R netto). Akun Kas/Bank sesuai pembayaran.

## 5. Filter daftar aktif (laporan yang sudah dibuat)
`dw_rpt_fa_register` & `dw_rpt_fa_rekap_gol`: tambah di WHERE → `AND a.status <> 'D'`
(atau `AND a.status IN ('A','F')`). Aset disposal otomatis hilang dari daftar aktif.

## 6. Laporan yang membedakan (a) / (b) / (c)
1. **Laporan Aktiva Aktif** (status A,F) — kolom "Ket. Status":
   `if(book_value>0,'Aktif','Habis Susut (Dipakai)')`.
2. **Laporan Aset Keluar / Disposal** (status D, dari FA_DISPOSAL + FA_ASSET):
   Kode, Nama, Tgl Perolehan, Harga, Akum saat keluar, NBV saat keluar, **Tgl Keluar, Jenis (Rusak/Dijual/…), Hasil (proceeds), Laba/Rugi**.

## 7. Proses window w_fa_disposal
1. Pilih aset dari daftar aktif (status A/F).
2. Sistem hitung `accum_dep` + `book_value` s/d bulan disposal (pastikan penyusutan s/d bulan itu sudah di-generate).
3. Input: tgl disposal, jenis, proceeds (bila dijual), alasan.
4. Simpan (1 transaksi):
   - INSERT `FA_DISPOSAL`
   - POST jurnal GL (voucher DSP…, modul FA)
   - UPDATE `FA_ASSET` SET status='D', disposal_date, remarks
   - `FA_DEPRECIATION` TETAP (histori aman).
5. Engine penyusutan: `sp_fa_generate_sl` sudah `WHERE status='A'` → aset 'D'/'F' otomatis tak disusutkan lagi.
6. **Batal Disposal** (sebelum closing): hapus FA_DISPOSAL + jurnal DSP, status kembali ke A/F.

## 8. Opening 2026 & koneksi ke rebuild FA_ASSET
- Opening 287 aset = Excel (rebuild). 
- 9 aset DB ekstra (Camry/Avanza/Kijang B2203) yang TAK ADA di Excel:
  - Bila **salah impor** → koreksi data (backup lalu bersihkan) — bukan disposal riil.
  - Bila **aset riil** yang seharusnya sudah keluar → set status='D' via proses disposal (dgn jurnal).
  Keputusan per-aset menyusul (lihat runbook rebuild).

## 9. Ringkas objek yang dibangun
- DB: tabel `FA_DISPOSAL` + (opsional) akun COA Laba/Rugi Pelepasan; proc `sp_fa_dispose` & `sp_fa_dispose_cancel`.
- PB: window `w_fa_disposal` (+ DW entry), report `dw_rpt_fa_disposal` (Arsip); tambah filter `status<>'D'` di 2 report aktif; kolom "Ket. Status".
- Semua audit-friendly: histori beli & penyusutan tak pernah dihapus.
