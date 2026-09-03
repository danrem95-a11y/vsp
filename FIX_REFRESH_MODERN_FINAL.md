# FIX REFRESH MODERN — FINAL (Costing Integrity GL = Stok, 2026)

> Recovery opening 2026 = **CLOSED/TERKUNCI** (tak disentuh). Dokumen final: dua jalur terpisah — **engine tetap per-bulan (monthly isolation)** + **repair SQL manual untuk data historis rusak**. Tanpa jurnal balancing/fiktif; tanpa transaksi baru; tidak sentuh WIP 102-020/HPP-WIP.

---

## 1. ROOT CAUSE FINAL (terbukti dari kode engine, bukan asumsi)
Gap movement 2026 **bukan** dari BTB/produk_id/currency (engine pakai `TSTOK2.STOK_ID` + `NETTO×KURS`; engine-BELI = GL_PO persis). **Akar = costing bernilai 0 untuk item yang dibeli & keluar HABIS dalam bulan yang sama:**
- Engine menghitung cost keluar dari **saldo (SINV) closing/opening** yang **sudah dinolkan** (rule `qty=0 → nilai=0`) → cost keluar = 0 → GL simpan nilai beli, stok kehilangan → **GL persediaan > stok**.
- Dua titik dengan pola sama:
  - **Step 4a** (`UPDATE HPP Penjualan reguler '22'`, TSALES2): HPP = `SINV.HPP_AVG @ :ldt_next` (closing) → 0 utk item habis-terjual. (mis. BF box 117,5jt; TS 45jt)
  - **Mutasi keluar '19'** (TSTOK2): NETTO = `SINV.HPP_AVG @ :ldt_tgl1` (opening) → 0 utk item beli-sebulan. (mis. TL.107-0334 12jt)

**Bukti:** BF box jual historis 2019-2024 HPP normal 38-90jt; hanya kasus beli-jual-sebulan =0. TL.107-0334: beli 10@1,2jt, '19' keluar 10 unit **netto 0**.

---

## 2. PERUBAHAN ENGINE (`n_cst_closing_stock.sru` — monthly-isolated)
Sumber cost dibuat **fallback dalam bulan berjalan saja**: pakai avg saldo bila >0, else **moving-avg (opening bulan ini + pembelian '02' bulan ini)/(qty)**. **Tidak** mengambil hpp_avg bulan lain.

| Lokasi | Sebelum | Sesudah |
|---|---|---|
| **Step 4a '22'** (baris ~355) SET | `HPP = ABS(ROUND(ISNULL(HPP.HRG,0),2))` | `HPP = ABS(ROUND(ISNULL(NULLIF(HPP.HRG,0), ISNULL(TSALES2.HPP,0)),2))` (guard: HRG=0 → **pertahankan HPP**, tak me-nol-kan) |
| **Step 4a '22'** subquery HRG | `SUM(HPP_AVG) FROM SINV WHERE PERIODE=:ldt_next` | `ISNULL(NULLIF(closing_avg,0), (opening_nilai+Σ BELI'02'×KURS bulan ini)/(opening_qty+Σ BELI_qty))` |
| **Mutasi '19'** subquery HRG (baris ~78) | `SUM(HPP_AVG) FROM SINV WHERE PERIODE=:ldt_tgl1` | `ISNULL(NULLIF(opening_avg,0), (opening_nilai+Σ BELI bulan ini)/(opening_qty+Σ BELI_qty))` |

- Backup: `n_cst_closing_stock.sru.bak_costing22` (asli), `.bak_costing22b` (sebelum guard).
- **Item normal (avg>0): nilai TIDAK berubah** (tanpa regresi). Item beli-keluar-sebulan: cost benar dari pembelian bulan ini.
- Perlu **PB 11.5 import + Full Build + deploy** (dipakai refresh klasik & modern).

## 3. KENAPA TIDAK ADA EFEK LINTAS BULAN
- Semua sumber cost engine hanya `SINV @ :ldt_tgl1/:ldt_next` (bulan yang di-refresh) + pembelian `TSTOK1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2` (bulan berjalan). **Tidak ada query hpp_avg bulan lain.**
- Refresh Januari **tidak** membaca Feb/Mar. Refresh Februari **tidak** membaca Jan (selain opening Feb, yang memang saldo awal bulan itu).
- Guard `NULLIF(HRG,0) → pertahankan HPP` membuat engine **tidak menyentuh** transaksi yang cost-nya tak tersedia bulan ini (diserahkan ke repair SQL) — bukan mengambil diam-diam dari bulan lain.
- **Idempotent & non-sirkular:** hitung ulang tiap refresh memberi hasil sama.

## 4. REPAIR SQL (data historis rusak — lintas periode) — `fix_cross_period_cost_repair.sql`
Untuk jual '22' HPP=0 yang **cost-basis-nya hanya di bulan sebelumnya** (engine per-bulan sengaja tak menyentuh). Contoh **102-101 `TS.102-1081`** (2 unit @ 5.316.287,84 = 10,63jt).
- Isi `tsales2.HPP` = **moving-avg valid terakhir** (`sinv.hpp_avg` periode ≤ bulan jual, >0) — **lintas-periode, MANUAL, bukan engine**.
- Guard engine step 4a menjaga hasil repair **tidak ditimpa** refresh (HRG bulan ini=0 → pertahankan HPP repair).
- Alur: **BACKUP** (`_tsales2_hpp_bak`) → **PREVIEW** → **APPLY** (hanya kandidat bercost) → **REFRESH** → **VERIFY** → **ROLLBACK** tersedia. Idempotent. Item legacy tanpa cost historis (mis. `LK.06.0004`) **tidak disentuh** (butuh keputusan akuntansi terpisah, nilai kecil).

## 5. VALIDASI SEBELUM/SESUDAH
**SEBELUM fix:** gap 6 akun ~211 jt (102-203 117,5 · 102-101 45,5 · 102-010 30,8 · 102-102 13,5 · 102-103 2,17 · 102-110 1,56).
**SESUDAH fix engine '22' (sudah live prod):** 102-203/010/103 = **0**; sisa 102-101 10,6 · 102-102 12 · 102-110 0,8 (~23jt).
**SESUDAH fix '19' + repair SQL (target):** 102-102 (TL.107-0334) tutup via '19'; 102-101/110 tutup via repair → **total gap ≤ Rp1**.
Guard tetap: **opening 102-001 = 12.999.133.239 · WIP 102-020 · HPP-WIP tidak berubah** (terverifikasi).
Validasi lengkap: **`validation_inventory_balance.sql`** (A movement=Rp1 · B HPP=0/mutasi-0 bercost = 0 · C WIP/opening tetap · D idempotent).

## 6. URUTAN DEPLOY (Pak Wira — COPY-DB dulu)
1. **PB 11.5 import** `n_cst_closing_stock.sru` → **Full Build** → deploy.
2. **COPY-DB:** jalankan `fix_cross_period_cost_repair.sql` (preview→apply) → **re-refresh Jan-Feb** → `validation_inventory_balance.sql`.
   - Cek: gap≤Rp1 semua akun · jual HPP=0-bercost=0 · mutasi'19'-nol-bercost=0 · WIP/opening tetap · idempotent.
3. Bila copy-DB bersih → **prod**: deploy build → repair SQL → re-refresh → validasi.

## 7. STATUS
- ✅ Engine '22' (step 4a) — **live di prod**, 3 akun tutup (~150jt).
- ✅ Engine '19' — **diterapkan di source** (belum build/deploy).
- ✅ `fix_cross_period_cost_repair.sql` + `validation_inventory_balance.sql` — siap.
- ⏳ Build + copy-DB test + re-refresh + validasi akhir = **Pak Wira** (agent write-block prod + tak bisa build PB).
- Catatan: step 4b (EVAP)/4c (Adjustment)/4d (Consin) punya pola sumber-cost serupa (`:ldt_next`/`:ldt_tgl1`) — **belum disentuh**; tinjau bila muncul gap di item EVAP/adjustment (di luar 6 akun ini). Residu kecil TL.203.0504 (~5jt, moving-avg blend qty) = isu data qty terdokumentasi terpisah.

## Berkas paket
`n_cst_closing_stock.sru` (engine fix '22'+'19') · `fix_cross_period_cost_repair.sql` · `validation_inventory_balance.sql` · `FIX_REFRESH_MODERN_FINAL.md` (ini) · backup `.bak_costing22`/`.bak_costing22b`.
