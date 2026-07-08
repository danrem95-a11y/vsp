# MANUAL PENGGUNA — Dashboard Rekonsiliasi VSP
**Modul:** Rekonsiliasi Stok / Hutang (AP) / Piutang (AR) vs Buku Besar (GL)
**Aplikasi:** VSP (PowerBuilder 11.5 + SQL Anywhere 9)
**Sifat:** READ-ONLY (hanya menampilkan & menelusuri; tidak mengubah data akuntansi)

---

## 1. Untuk apa modul ini?
Memastikan **saldo subledger = saldo Buku Besar (GL)** untuk 3 area, dan bila ada **selisih**, menelusurinya **sampai baris jurnal / voucher** dengan cepat.

- **Stok:** total nilai persediaan (kartu stok/SINV) vs akun persediaan di GL.
- **Hutang (AP):** total sisa faktur beli per supplier vs akun hutang GL.
- **Piutang (AR):** total sisa faktur jual per customer vs akun piutang GL.

Tujuan utama: **menemukan sumber selisih** (mis. voucher yang belum dijurnal) tanpa mengaduk-aduk laporan manual.

---

## 2. Istilah penting
| Istilah | Arti |
|---|---|
| **Subledger** | Angka dari buku pembantu (kartu stok, opname hutang/piutang). |
| **Ledger (GL)** | Saldo akun di Buku Besar = saldo awal tahun + mutasi jurnal terposting. |
| **Selisih** | Subledger − Ledger. Idealnya **0**. |
| **COCOK / SELISIH** | Status baris. **COCOK** bila |selisih| ≤ **Rp 10** (toleransi pembulatan). |
| **GATE 1 / 2 / 3** | Lampu pemeriksaan mutu angka (lihat §7). |
| **Anomali (R1–R11)** | Klasifikasi otomatis penyebab selisih. |
| **Snapshot** | Foto angka rekonsiliasi per periode (dibaca dashboard biar cepat). |

> **Aturan emas:** modul ini tidak memperbaiki data. Koreksi tetap lewat modul transaksi/jurnal resmi. Modul ini menunjukkan **APA** yang salah dan **DI MANA**.

---

## 3. Membuka modul
1. Login ke aplikasi VSP seperti biasa.
2. Di **menu kiri**, buka grup **REKONSILIASI**:
   - **Dashboard Rekonsiliasi** — layar utama.
   - **Anomali (R1-R11)** — daftar penyebab selisih.
   - **Snapshot Rekonsiliasi** — riwayat & pembangunan snapshot.

> Jika menu belum muncul: pastikan hak akses menu sudah diberikan ke user Anda, lalu **logout → login ulang** (menu dimuat saat login).

---

## 4. Alur kerja singkat
```
Dashboard (ringkasan 3 domain, per periode)
   └─ klik-2x baris domain  → daftar per Vendor / Customer / Akun
        └─ klik-2x entitas   → daftar Voucher / Faktur
             └─ klik-2x voucher → Baris Jurnal GL  ← titik bukti (audit)
   Tombol "Anomali"  → penyebab selisih (R1–R11) → klik-2x = voucher sumbernya
   Tombol "Snapshot" → riwayat periode + tombol "Build Snapshot"
```
"klik-2x" = **double-click** pada baris.

---

## 5. Layar Dashboard
Menampilkan **1 baris per domain** (STOK, AP, AR) untuk **periode** terpilih.

**Kolom:**
- **Subledger** — total buku pembantu.
- **Ledger (GL)** — saldo Buku Besar.
- **Selisih** — Subledger − Ledger.
- **Status** — COCOK / SELISIH.
- **GATE1 / GATE2 / GATE3** — PASS / FAIL / NA.

**Kontrol di atas layar:**
- **Periode** — isi tanggal periode (format `YYYY-MM-DD`, mis. `2026-04-01`), lalu klik **Tampilkan**.
- **Tampilkan** — memuat/menyegarkan angka periode tsb (dari snapshot).
- **Anomali** — membuka panel R1–R11 untuk periode itu.
- **Snapshot** — membuka layar riwayat/Build snapshot.

**Cara baca:**
- Baris **COCOK** → domain itu seimbang, tidak perlu tindakan.
- Baris **SELISIH** → ada beda; **double-click** baris untuk menelusuri.

> Dashboard membaca **snapshot**. Bila periode belum pernah di-*Build*, angka bisa kosong — bangun dulu di layar **Snapshot** (§8).

---

## 6. Menelusuri sumber selisih (drill-down)
Ini fitur inti. Dari baris **SELISIH** di dashboard:

**Langkah 1 — double-click baris domain:**
- **AP** → daftar **per Vendor** (kolom: Vendor, Sisa Hutang).
- **AR** → daftar **per Customer** (Customer, Sisa Piutang).
- **STOK** → daftar **per Akun Persediaan** (Akun, Subledger, Ledger, Selisih, Status) — langsung kelihatan akun mana yang beda.

**Langkah 2 — double-click entitas** (vendor/customer): tampil **daftar voucher/faktur** entitas itu, dengan kolom **Sub?** (Y/N):
- **Sub? = N** → voucher yang **tidak punya pasangan jurnal GL** (kandidat sumber selisih).

**Langkah 3 — double-click voucher:** tampil **baris Jurnal GL** (tanggal, modul, debet, kredit, voucher). Ini **titik bukti**: di sinilah subledger bertemu (atau tidak bertemu) GL.

Untuk **STOK**, double-click akun langsung membuka baris jurnal GL akun tsb.

**Kolom "Anchor"** pada layar jurnal:
- `INVOICE` = jurnal faktur, `PAYMENT` = jurnal pembayaran, `OPENING` = saldo awal, `ORPHAN` = jurnal GL tanpa pasangan subledger (perlu diperiksa).

---

## 7. Arti GATE (lampu mutu)
| GATE | Arti | PASS berarti | FAIL berarti |
|---|---|---|---|
| **GATE 1** | Laporan vs mesin hitung | Angka view = laporan opname | Perlu cek konsistensi laporan |
| **GATE 2** | Subledger vs GL | Seimbang (selisih ≤ Rp10) | **Ada selisih riil** → telusuri / lihat Anomali |
| **GATE 3** | Integritas pemetaan akun | Semua akun terpetakan benar | Ada akun belum dipetakan/kadaluarsa |

> **GATE 2 = FAIL bukan berarti aplikasi rusak** — justru artinya modul berhasil **mendeteksi** selisih yang memang harus ditindaklanjuti akuntansi.

---

## 8. Panel Anomali (R1–R11)
Tombol **Anomali** menampilkan daftar penyebab selisih yang terdeteksi otomatis. Kolom: **Rule, Severity, Kategori, Domain, Akun, Ref Key, Nilai**.

**Arti tiap aturan (ringkas):**
| Rule | Kategori | Artinya / tindakan |
|---|---|---|
| R1 | UNPOSTED_JOURNAL | Ada jurnal belum diposting → posting dulu. |
| R2 | MISSING_LEDGER | Mutasi stok ada, jurnal GL kosong. |
| R3 | OPENING_BALANCE_GAP | Selisih saldo awal tahun (mis. pos lama/MAT). |
| R4 | GL_ONLY_NO_SINV | Akun GL tanpa data stok (mis. WIP) — info. |
| R5 | LOOP19_RISK | Risiko nilai costing tidak stabil — cek. |
| R6 | SITE_MISMATCH | Beda site GL vs saldo. |
| R7 | PAYMENT_PENDING | Pembayaran masih pending. |
| R8 | ADJUSTMENT_PUTIH | Penyesuaian non-kas. |
| R9 | GL_ORPHAN_VOUCHER | Jurnal GL tanpa pasangan faktur → periksa. |
| R10 | ROUNDING_NOISE | Selisih ≤ Rp10 (abaikan). |
| **R11** | **DP_APPLICATION_GAP** | **Uang Muka (DP) mengurangi subledger tapi belum dijurnal GL** → posting jurnal DP. |

**Cara pakai:** double-click baris anomali → muncul **voucher sumber** (kolom Ref Key, mis. `vmanual=2605DPR002`) dan nilainya. Serahkan voucher ini ke bagian akuntansi untuk diposting/dikoreksi.

**Warna Severity:** HIGH = merah (prioritas), MED = kuning, INFO = abu.

---

## 9. Layar Snapshot (riwayat & Build)
- Menampilkan **riwayat rekonsiliasi lintas periode** (periode, domain, subledger, ledger, selisih, status GATE) — untuk audit/tren.
- **Tombol "Build Snapshot":** menghitung ulang snapshot untuk **periode** pada filter, lalu menyimpannya. **Jalankan setiap selesai closing/refresh** agar dashboard menampilkan angka terkini.
- **Tombol "Tampil":** menyegarkan tampilan riwayat.

> **Build sebaiknya dilakukan admin/petugas yang ditunjuk**, satu kali per periode setelah proses closing/refresh stok & jurnal.

---

## 10. Cetak & Export
Setiap layar (report) mewarisi fitur standar aplikasi:
- **Cetak** — mencetak isi tabel (kertas kerja).
- **Export Excel** — mengekspor tabel ke Excel untuk arsip/audit.

(Tombol ada di toolbar report seperti laporan VSP lain.)

---

## 11. Contoh kasus nyata (baseline)
Pada periode **April 2026** (data uji), dashboard menunjukkan **SELISIH / GATE2 FAIL** — dan ini **benar**, penyebabnya sudah teridentifikasi:
- **Piutang (AR):** selisih ≈ **459,86 jt** = **9 voucher Uang Muka (DPR)** yang mengurangi piutang tapi belum berjurnal GL (Anomali **R11**).
- **Hutang (AP):** selisih ≈ **1.324,50 jt** = **5 voucher Uang Muka (DPB)** belum berjurnal GL (Anomali **R11**).
- **Stok:** selisih ≈ **23,96 jt** = pos historis 2018 (**MAT**) di saldo awal (Anomali **R3**), bukan kesalahan transaksi berjalan.

**Tindakan akuntansi:** buka Anomali → catat 14 voucher DP → posting jurnal DP → Build Snapshot ulang → selisih AP/AR menjadi 0.

---

## 12. Peran & tanggung jawab
| Peran | Tugas |
|---|---|
| **Admin/IT** | Build snapshot pasca-closing; kelola hak akses menu. |
| **Akuntansi** | Baca dashboard, telusuri selisih, tindak lanjuti anomali (posting/koreksi lewat modul resmi). |
| **Auditor** | Pakai drill-down & riwayat snapshot sebagai kertas kerja. |

---

## 13. Troubleshooting / FAQ
- **Menu Rekonsiliasi tidak muncul** → minta hak akses menu, lalu **logout/login**.
- **Dashboard kosong / angka 0** → snapshot periode belum di-*Build*. Buka layar Snapshot → isi periode → **Build Snapshot**.
- **Angka tidak berubah setelah posting jurnal** → **Build Snapshot** ulang untuk periode tsb (dashboard baca snapshot, bukan hitung langsung).
- **Semua GATE2 FAIL** → normal bila memang ada selisih; lihat Anomali untuk penyebab. Bukan error aplikasi.
- **Ada baris "ORPHAN" di jurnal** → jurnal GL tanpa pasangan faktur; laporkan ke akuntansi untuk diperiksa.
- **Selisih kecil ≤ Rp 10** → pembulatan, diabaikan (status tetap COCOK).

---
*Modul read-only. Semua angka dapat ditelusuri sampai baris `gl_journal`. Koreksi data hanya melalui modul transaksi/jurnal resmi VSP.*
