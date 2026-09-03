-- ============================================================================
-- fix_costing_2026.sql -- KOREKSI SUMBER COGS (tsales2.HPP=0) -> moving-average
-- Root cause: penjualan '22' ber-HPP=0 pada item ber-cost-basis => COGS tak terbukukan;
--   engine rule qty=0->nilai=0 hapus nilai beli dari stok, GL simpan nilai => GL persediaan > stok.
-- Perbaikan = SUMBER TRANSAKSI (tsales2.HPP), lalu REFRESH RESMI. TANPA jurnal balancing/fiktif.
-- LARANGAN: tidak menyentuh opening 2026, Desember 2025, WIP 102-020, HPP-WIP ('88').
-- !!! JALANKAN DI COPY-DB DULU. Verifikasi property('MachineName') = mesin TEST. !!!
-- Parameter periode: ubah 2 baris SET di STEP 0.
-- ============================================================================

-- ==== PARAMETER ====
IF VAREXISTS('p_from')=1 THEN DROP VARIABLE p_from END IF;
IF VAREXISTS('p_to')=1   THEN DROP VARIABLE p_to   END IF;
CREATE VARIABLE p_from DATE; SET p_from='2026-01-01';   -- awal periode koreksi
CREATE VARIABLE p_to   DATE; SET p_to  ='2026-02-28';   -- akhir periode koreksi

-- ==== moving-average periode per item (cara engine: NETTO*KURS; BELI '02') ====
-- mavg = (opening_nilai + BELI_nilai periode) / (opening_qty + BELI_qty periode)
--   dihitung dari sumber; item TANPA cost-basis (mavg=0/null) TIDAK dikoreksi (mis. WIP reefer, model dasar).
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_mavg') THEN DROP TABLE _mavg END IF;
SELECT x.stok_id,
  cast((isnull(o.onil,0)+isnull(b.bnil,0)) / nullif(isnull(o.oqty,0)+isnull(b.bqty,0),0) as numeric(18,4)) mavg
INTO _mavg
FROM (SELECT DISTINCT STOK_ID stok_id FROM tstok2) x
LEFT JOIN (SELECT stok_id, sum(isnull(qty,0)) oqty, sum(isnull(nilai,0)) onil FROM sinv WHERE periode=p_from GROUP BY stok_id) o ON o.stok_id=x.stok_id
LEFT JOIN (SELECT t2.STOK_ID sid, sum(isnull(t2.QTY,0)) bqty, sum(isnull(t2.NETTO,0)*isnull(t1.KURS,1)) bnil
           FROM tstok1 t1 JOIN tstok2 t2 ON t2.BUKTI_ID=t1.BUKTI_ID
           WHERE t1.TIPE_TRANS='02' AND isnull(t1.ORDER_OKE,'N')='Y' AND t1.TGL BETWEEN p_from AND p_to GROUP BY t2.STOK_ID) b ON b.sid=x.stok_id;
COMMIT;

-- ==== kandidat: jual '22' HPP=0, item ber-cost-basis (mavg>0), BUKAN WIP ('88'), BUKAN akun 102-020 ====
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_fixcand') THEN DROP TABLE _fixcand END IF;
SELECT s2.BUKTI_ID, s2.URUT, s2.STOK_ID, gr.persediaan akun, s1.TGL, s1.USER_ID,
       cast(s2.QTY as numeric(14,2)) qty, cast(isnull(s2.HPP,0) as numeric(14,2)) hpp_lama,
       cast(m.mavg as numeric(16,4)) hpp_baru, cast(s2.QTY*m.mavg as numeric(18,2)) nilai_koreksi
INTO _fixcand
FROM tsales2 s2 JOIN tsales1 s1 ON s1.BUKTI_ID=s2.BUKTI_ID
JOIN im_produk pr ON pr.produk_id=s2.STOK_ID JOIN im_product_group gr ON gr.kode_group=pr.group_product
JOIN _mavg m ON m.stok_id=s2.STOK_ID
WHERE s1.TIPE_TRANS='22' AND isnull(s2.HPP,0)=0 AND s1.TGL BETWEEN p_from AND p_to
  AND m.mavg>0 AND gr.persediaan<>'102-020';
COMMIT;

-- STEP 0: BACKUP (tsales2 baris kandidat + sinv periode terdampak)
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_tsales2_bak') THEN DROP TABLE _tsales2_bak END IF;
SELECT s2.* INTO _tsales2_bak FROM tsales2 s2 WHERE EXISTS(SELECT 1 FROM _fixcand f WHERE f.BUKTI_ID=s2.BUKTI_ID AND f.URUT=s2.URUT);
COMMIT;

-- STEP 1: PREVIEW (voucher/tanggal/item/hpp lama/hpp baru/nilai koreksi) -- BACA & SETUJUI
SELECT akun, STOK_ID, BUKTI_ID, TGL, USER_ID, qty, hpp_lama, hpp_baru, nilai_koreksi FROM _fixcand ORDER BY akun, TGL, STOK_ID;
-- ringkas dampak per akun (perkiraan penurunan gap = kenaikan COGS)
SELECT akun, count(*) n, cast(sum(nilai_koreksi) as numeric(20,2)) total_cogs_koreksi FROM _fixcand GROUP BY akun ORDER BY akun;

-- STEP 2: APPLY -- SATU-SATUNYA penulisan sumber. Isi tsales2.HPP = moving-average (hanya kandidat).
--   (buka komentar setelah PREVIEW disetujui)
-- UPDATE tsales2 SET HPP = f.hpp_baru FROM _fixcand f WHERE tsales2.BUKTI_ID=f.BUKTI_ID AND tsales2.URUT=f.URUT;
-- COMMIT;

-- STEP 3: REFRESH RESMI (aplikasi/NVO) periode p_from..p_to -> re-post COGS + recompute sinv.
--   TIDAK menyentuh opening 2026 / Des 2025 / WIP. (Lihat RUNBOOK / CLOSING_STOCK_CONTROL.md)

-- STEP 4: VALIDASI (lihat validation_costing.sql): GL_mov=stock_mov per akun (<=Rp1),
--   WIP 102-020 tetap, HPP-WIP tetap, opening 2026 tetap, idempotent.

-- ROLLBACK: UPDATE tsales2 SET HPP=b.HPP FROM _tsales2_bak b WHERE tsales2.BUKTI_ID=b.BUKTI_ID AND tsales2.URUT=b.URUT; COMMIT;
