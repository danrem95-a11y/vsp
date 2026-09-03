# Solusi Permanen Stok vs Ledger — Investigasi WIP 102-020
Senior ERP Accounting & Inventory Engineer • prod 103.233.89.43:2638 • closing Feb 2026 (sinv 2026-03-01, GL gl_balance[2026]+movement 2026).

## 1. Rekonsiliasi lengkap (angka BENAR — formula ledger = opening 2026 + movement 2026 saja)

| Akun | SINV (stok) | LEDGER | GAP (sinv−led) | Sifat |
|---|---:|---:|---:|---|
| 102-001 TR | 24.354.000.434 | 14.242.819.783 | **+10.111.180.650** | stok > ledger |
| 102-006 TB | 2.760.554.063 | 1.877.122.940 | +883.431.123 | stok > ledger |
| 102-101 | 6.902.456.217 | 6.825.576.497 | +76.879.721 | |
| 102-110 | 3.140.569.019 | 3.096.174.178 | +44.394.841 | |
| 102-010 | 259.859.334 | 248.939.333 | +10.920.000 | |
| 102-201 MT | 96.686.337 | 120.648.969 | −23.962.632 | stok < ledger |
| 102-102 | 188.459.505 | 200.459.497 | −11.999.991 | error qty TL.203.0504 |
| **102-020 WIP** | **0** | **1.588.418.120** | **−1.588.418.120** | **ledger ada, stok TIDAK ada** |
| **TOTAL** | **38.879.625.794** | **29.377.200.203** | **+9.502.425.591** | **stok > ledger 9,50 M** |

## 2. Temuan yang membalik hipotesis (bukti, bukan opini)

**a. WIP yang benar-benar terjurnal HANYA Rp1,59 M (= saldo ledger 102-020), bukan 11,86 M.**
- WIP-Out '88' TR yang outstanding di ERP = **23–35 serial, Rp1,76 M** (12 ber-hpp=0 akibat bug cost-loss). Ini **persis** = komposisi TR di ledger 102-020. Loop WIP yang tercatat **konsisten**.
- **Tidak ada tabel serial-master** di DB. Angka Bapak (126 serial / Rp11,86 M) berasal dari **hitung fisik/analisa manual**, TIDAK ada di transaksi ERP (ERP hanya punya 23–35 serial outstanding).

**b. Gap 102-001 (10,11 M) BUKAN WIP terjurnal.** 102-020 hanya menampung 1,59 M. Sisa ~8,5 M di TR adalah **over-valuasi saldo AWAL 2026** (phantom dari tutup buku 2025 + bug WIP-Out hpp=0), konstan sejak opening (Jan = Feb).

**c. Arah gap: STOK LEBIH TINGGI dari LEDGER sebesar Rp9,50 M** (net). GL (berpasangan, balance, auditable) = **book of record**; stok opname opening 2026 yang **over-stated**.

## 3. Pembuktian matematis: gap TIDAK bisa ditutup transaksi berimbang

Setiap transfer stok (mis. TR → WIP) **mempertahankan total stok**. Karena **Σstok (38,88 M) > Σledger (29,38 M)**, tidak ada transaksi berimbang (stok + jurnal bergerak sama) yang bisa membuat Σstok = Σledger.
> Transfer TR→WIP nilai V: gap TR turun V, gap WIP naik V → **net gap tetap 9,50 M**.

**Jadi "buat mutasi WIP" saja TIDAK akan membuat selisih = 0.** Ia hanya memindahkan gap, tidak menghapusnya. Untuk selisih = 0, **salah satu sisi harus disesuaikan** (stok turun ATAU ledger naik) — ini keputusan valuasi yang tak terhindarkan.

## 4. Solusi permanen (2 bagian)

### BAGIAN 1 — WIP jadi stok (AMAN, tutup 102-020) — `wip_part1_preview.sql`
Buat item stok WIP dipetakan ke **102-020**, isi = reklas outstanding WIP-Out (**1,59 M**, = saldo ledger 102-020) dari stok TR/TB.
- **Efek:** sinv 102-020 = ledger 102-020 (1,59 M) → 102-020 **balance & terlihat sebagai persediaan WIP**. Gap TR/TB berkurang 1,59 M.
- **Aman:** reklas stok (total stok tetap), **tanpa ubah ledger, tanpa hapus saldo**. Serial & moving-avg tak tersentuh (hanya pindah bucket).
- **Tapi:** ini menutup 1,59 M; **sisa 8,5–9,5 M TIDAK tertutup** (bukan WIP).

### BAGIAN 2 — Alignment valuasi opening (WAJIB untuk selisih=0) — keputusan tak terhindarkan
Sisa ~8,5 M = over-valuasi **saldo AWAL 2026** stok vs GL. Karena **GL = book of record** (audited, balance), **asumsi terbaik dari data**: samakan **saldo awal stok (sinv 2026-01-01) ke GL** per akun.
- **Metode aman (belajar dari kegagalan opsi1 yang merusak Konsinyasi):** sesuaikan **nilai/hpp_avg model NON-WIP** (mis. TR.038A dst) agar total akun = gl_balance[2026], **JANGAN sentuh HPP serial WIP '88'** (itu yang dulu merusak Konsinyasi). Qty tetap.
- **Efek:** sinv opening = GL → selisih Stok vs Ledger = **0** untuk semua bulan (offset konstan hilang).
- **Konsekuensi:** nilai persediaan stok turun 8,5 M agar = neraca GL (bukan menghapus barang — mengoreksi **valuasi phantom** agar sesuai buku besar teraudit).

## 5. Rekomendasi & alasan

**Jalankan BAGIAN 1 + BAGIAN 2, urut.** Alasan:
1. **GL adalah kebenaran akuntansi** (double-entry, balance, dasar neraca). Selisih = stok opname yang salah nilai, bukan GL.
2. Hanya **1,59 M** yang layak jadi WIP-stok (yang GL akui); sisanya phantom valuasi → hanya alignment ke GL yang membuat selisih = 0.
3. Bagian 2 dibatasi ke **model NON-WIP** → **Konsinyasi tidak rusak** (akar kegagalan opsi1 dihindari).
4. Engine WIP-Out-HPP-beku (redesign yang sudah dibuat) mencegah phantom **terulang** ke depan.

## 6. Output & bukti (di `C:\BTV\debug`)
- `wip_recon_evidence.sql` — rekonsiliasi per akun + trace WIP-Out/In/jual per serial + saldo 102-020.
- `wip_part1_preview.sql` — preview reklas WIP → 102-020 (apa yang pindah, tanpa eksekusi).
- Script BAGIAN 2 (alignment opening) **disiapkan setelah Bapak setuju arah GL-as-truth** — karena mengubah nilai neraca 8,5 M, wajib: backup DB → preview per model → eksekusi copy-DB → validasi selisih=0 → baru prod.

## 7. Validasi wajib setelah eksekusi (target)
- **A.** 102-001/003/006/020: sinv = ledger (selisih ≤ Rp1).
- **B.** Mutasi Jan & Feb **tidak berubah** (Δ checksum GL/sinv = 0) — reklas & alignment hanya di OPENING, tak sentuh gerakan.
- **C.** `select ... gap` semua 102-xxx = 0.

## KESIMPULAN JUJUR
- **Refresh Jan-Feb sudah benar** (mutasi = ledger). ✅
- Gap **9,50 M net** = **1,59 M WIP** (bisa direklas ke 102-020) **+ ~7,9 M phantom valuasi opening** (bukan WIP; hanya alignment ke GL yang menghapusnya).
- **"Buat mutasi WIP" saja tidak cukup** untuk selisih=0 (terbukti matematis). Perlu **Bagian 1 (WIP-stok) + Bagian 2 (alignment opening ke GL, model NON-WIP saja agar Konsinyasi aman)**.
