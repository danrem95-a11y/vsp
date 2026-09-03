# CLOSING STOCK CONTROL — Costing Integrity GL = Stok (2026)

> Recovery opening 2026 = **CLOSED/TERKUNCI**. Dokumen ini: penyebab, fix sumber, **fix engine permanen + guard**, prosedur closing, validasi, rollback. Semua koreksi = **sumber transaksi**, tanpa jurnal balancing/fiktif; tidak menyentuh opening 2026 / Des 2025 / WIP 102-020 / HPP-WIP.

---

## 1. PENYEBAB (terbukti dari engine, bukan asumsi)
- Engine `dw_refresh_stok` pakai **`TSTOK2.STOK_ID`** (bukan produk_id) & **`NETTO×ISNULL(KURS,1)`** → **pembelian sinkron GL=stok** (engine-BELI = GL_PO persis 6 akun). Jadi produk_id/currency **bukan** penyebab.
- **Root cause = penjualan '22' ber-`tsales2.HPP=0`** pada item ber-cost-basis → COGS tak terbukukan. Saat qty net=0, NVO rule **`qty=0→nilai=0`** menghapus nilai beli dari stok; GL simpan nilai (tak ada COGS) → **GL persediaan > stok**.
- Bukti koreksi COGS (moving-avg) menutup gap PERSIS: **102-203 117,5jt · 102-101 45,52jt · 102-010 30,8jt · 102-103 2,17jt** (~196jt dari ~211jt). Sisa 102-102 12jt / 102-110 0,81jt = item lain (re-refresh + telaah kecil).
- **HPP=0 yang BENAR (jangan disentuh):** WIP reefer 102-001 (TR.038/TR.039, mekanisme '88'), model dasar tanpa cost. Karena itu fix **hanya** untuk item dengan moving-avg>0 & akun<>102-020.

---

## 2. FIX ENGINE PERMANEN (self-correcting) — di NVO `n_cst_closing_stock.of_run`
Sisipkan **SEBELUM** retrieve `dw_refresh_stok` (paralel dengan freeze '88' yang sudah ada). Isi HPP jual '22' dari moving-avg periode bila 0 & item ber-cost-basis. Idempoten (yang sudah >0 dilewati).

```sql
-- === FIX COSTING '22': isi HPP jual dari moving-average periode bila HPP=0 & item ber-cost-basis ===
UPDATE TSALES2
   SET HPP = M.MAVG
  FROM TSALES2, TSALES1,
       ( SELECT X.STOK_ID,
                ( ISNULL(O.ONIL,0) + ISNULL(B.BNIL,0) )
                / NULLIF( ISNULL(O.OQTY,0) + ISNULL(B.BQTY,0), 0 ) AS MAVG
           FROM ( SELECT DISTINCT STOK_ID FROM TSTOK2 ) X
           LEFT JOIN ( SELECT STOK_ID, SUM(ISNULL(QTY,0)) OQTY, SUM(ISNULL(NILAI,0)) ONIL
                         FROM SINV WHERE PERIODE = :ldt_tgl1 GROUP BY STOK_ID ) O ON O.STOK_ID = X.STOK_ID
           LEFT JOIN ( SELECT T2.STOK_ID SID, SUM(ISNULL(T2.QTY,0)) BQTY,
                              SUM(ISNULL(T2.NETTO,0)*ISNULL(T1.KURS,1)) BNIL
                         FROM TSTOK1 T1, TSTOK2 T2
                        WHERE T1.BUKTI_ID=T2.BUKTI_ID AND T1.TIPE_TRANS='02'
                          AND ISNULL(T1.ORDER_OKE,'N')='Y' AND T1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2
                        GROUP BY T2.STOK_ID ) B ON B.SID = X.STOK_ID
       ) M
 WHERE TSALES2.BUKTI_ID = TSALES1.BUKTI_ID
   AND TSALES1.TIPE_TRANS = '22'
   AND TSALES1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2
   AND ISNULL(TSALES2.HPP,0) = 0
   AND TSALES2.STOK_ID = M.STOK_ID
   AND M.MAVG > 0 ;
IF sqlca.sqlcode = 0 THEN commit; ELSE rollback; of_cleanup(); RETURN -1 END IF
```

> Efek: refresh berikutnya **otomatis** membukukan COGS benar → GL=stok; historis pun sembuh saat re-refresh. Tidak menyentuh '88'/102-020.

---

## 3. GUARD PERMANEN (tolak closing bila sumber salah)

### Guard 1 — SALES WITHOUT COSTING (setelah fix §2, sebelum lanjut refresh)
```sql
SELECT COUNT(*) INTO :ll_nocost FROM TSALES2 S2, TSALES1 S1, SINV SV
 WHERE S1.BUKTI_ID=S2.BUKTI_ID AND S1.TIPE_TRANS='22'
   AND S1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2
   AND ISNULL(S2.HPP,0)=0 AND ISNULL(S2.QTY,0)>0
   AND SV.STOK_ID=S2.STOK_ID AND SV.PERIODE=:ldt_tgl1 AND ISNULL(SV.HPP_AVG,0)>0 ;
```
Jika `ll_nocost > 0` → **REFRESH FAILED**, tampilkan voucher/item:
`ERROR: SALES WITHOUT COSTING — Voucher <BUKTI_ID> Item <STOK_ID>`. Jangan lanjut.

### Guard 2 — STOCK vs GL MOVEMENT (akhir closing, sebelum finalisasi)
Per akun persediaan hitung `GL movement` vs `Stock movement` (lihat `validation_costing.sql` bag. A). Jika `ABS(selisih) > 1` untuk akun mana pun → **CLOSING FAILED** (blokir posting laporan).

### Guard 3 — COSTING INTEGRITY (per baris jual bercost)
`qty_keluar × average_cost = pengurangan_nilai_inventory`. Jika untuk item ber-`hpp_avg>0` ada `HPP=0` (COGS≠qty×avg) → tandai/fail (subset Guard 1).

---

## 4. KOREKSI HISTORIS (data lama) — `fix_costing_2026.sql`
Untuk data Jan-Feb 2026 yang sudah terlanjur: backup → **preview** (voucher/tgl/item/hpp lama/hpp baru/nilai koreksi) → **apply** (isi `tsales2.HPP`=moving-avg, hanya kandidat ber-cost-basis, bukan 102-020/'88') → **refresh resmi** → **validasi** (`validation_costing.sql`). Alternatif: cukup pasang fix engine §2 lalu **re-refresh** periode → historis sembuh otomatis.

---

## 5. PROSEDUR CLOSING (baru)
1. Input transaksi bulan berjalan.
2. Refresh/closing menjalankan **FIX §2** (isi HPP jual) → **Guard 1** → engine `dw_refresh_stok` → tulis sinv.
3. **Guard 2** (GL-mov=stock-mov per akun ≤ Rp1). Jika gagal → perbaiki sumber, ulang. Jangan posting.
4. Baru posting laporan.

## 6. VALIDASI (DoD)
`validation_costing.sql`: **A** GL_mov=stock_mov ≤Rp1 semua akun · **B** WIP 102-020 & HPP-WIP tetap · **C** opening 2026 tetap (= recovery Mekanisme A) · **D** idempotent (ulang → 0 kandidat, checksum sinv identik).

## 7. ROLLBACK
`UPDATE tsales2 SET HPP=b.HPP FROM _tsales2_bak b WHERE tsales2.BUKTI_ID=b.BUKTI_ID AND tsales2.URUT=b.URUT; COMMIT;` lalu re-refresh.

## 8. STATUS & BATAS (jujur)
- **Terbukti (prod read-only):** algoritma koreksi menutup gap PERSIS 4/6 akun (196jt/211jt). Sisa 102-102(12jt)/110(0,8jt) = telaah item + re-refresh.
- **Belum dieksekusi:** apply + refresh + validasi akhir = **di COPY-DB lalu prod oleh Pak Wira** (agent write-blocked prod; fix engine §2 perlu **build PB**). 
- **End state ditargetkan:** GL = Stock = Engine, closing berikut **otomatis gagal** bila sumber salah (Guard 1/2). Opening 2026 & WIP tidak disentuh.

## Berkas paket
`fix_costing_2026.sql` (koreksi historis) · `validation_costing.sql` (validasi) · `CLOSING_STOCK_CONTROL.md` (ini; fix engine + guard) · `HPP0_candidates_2026.csv` / `HPP0_AUDIT_CANDIDATES.md` (daftar) · `MOVEMENT_GAP_FIX_DESIGN.md` (desain).
