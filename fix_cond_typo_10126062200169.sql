-- ============================================================================
-- FIX TYPO COND — Faktur konsinyasi 10126062200169 (LINTAS MITRA, NR.201A)
-- DB: vsp (DSN vsp, dba) | Analisa: 2026-07-23
-- ----------------------------------------------------------------------------
-- MASALAH:
--   WIP In tidak terbentuk utk faktur ini -> nilai Rp53.000.000 tidak masuk
--   mutasi stok/GL -> menyumbang selisih Mutasi Stok vs Ledger Juni 2026.
--
-- ROOT CAUSE (terverifikasi):
--   f_insert_cons_in menjoin faktur<->WIP Out dgn syarat EVAP DAN COND sama.
--   Di faktur 10126062200169 URUT=2 (NR.201A):
--     EVAP = '645BDEAC002'  (BENAR, = WIP Out 10126058800063)
--     COND = '64B5DEAC002'  (TYPO: huruf 'B' dan angka '5' tertukar posisi)
--   Krn COND != EVAP dan != WIP Out.COND, join gagal -> WIP In tak narik.
--   Verifikasi: dari 327 baris konsinyasi 2026, HANYA 1 ini yg EVAP<>COND.
--   ASCII COND posisi 1-6 = 6,4,B,5,D,E (64B5DE) vs seharusnya 645BDE.
--
-- WIP Out yg benar (target match): 10126058800063 (09-Mei-2026, NR.201A,
--   EVAP=COND='645BDEAC002').
--
-- TARGET UPDATE (paling aman via URUT, bukan via nilai COND yg rawan):
--   TSALES2 WHERE BUKTI_ID='10126062200169' AND URUT=2
-- ============================================================================
-- Jalankan di dbisql (DSN vsp) sebagai transaksi manual. JANGAN autocommit.
-- ============================================================================

-- ---------- STEP 1: BASELINE (catat sebelum ubah) --------------------------
SELECT BUKTI_ID, URUT, STOK_ID, EVAP, COND, QTY
FROM TSALES2 WHERE BUKTI_ID='10126062200169' AND URUT=2;
-- Harapan: 1 baris, EVAP='645BDEAC002', COND='64B5DEAC002'.

-- Pastikan hanya 1 baris yg jadi target (guard):
SELECT COUNT(*) AS n_target
FROM TSALES2 WHERE BUKTI_ID='10126062200169' AND URUT=2 AND EVAP='645BDEAC002';
-- Harapan: 1.


-- ---------- STEP 2: KOREKSI COND = EVAP ------------------------------------
-- Samakan COND dgn EVAP (nilai benar). Pakai EVAP sbg sumber agar 100% konsisten.
UPDATE TSALES2
   SET COND = EVAP
 WHERE BUKTI_ID = '10126062200169'
   AND URUT = 2
   AND STOK_ID = 'NR.201A'
   AND EVAP = '645BDEAC002'
   AND COND <> EVAP;


-- ---------- STEP 3: VERIFIKASI (sebelum commit) ----------------------------
-- (a) COND kini = EVAP:
SELECT BUKTI_ID, URUT, STOK_ID, EVAP, COND,
       CASE WHEN EVAP=COND THEN 'OK-SAMA' ELSE 'MASIH BEDA' END status
FROM TSALES2 WHERE BUKTI_ID='10126062200169' AND URUT=2;
-- Harapan: status OK-SAMA, COND='645BDEAC002'.

-- (b) Sekarang faktur MATCH dgn WIP Out (syarat WIP In narik):
SELECT
 (SELECT COUNT(*) FROM TSALES1 wo JOIN TSALES2 wb ON wb.BUKTI_ID=wo.BUKTI_ID
   WHERE wo.TIPE_TRANS='88' AND wb.STOK_ID='NR.201A'
     AND wb.EVAP='645BDEAC002' AND wb.COND='645BDEAC002') AS n_wipout_match;
-- Harapan: >= 1 (WIP Out 10126058800063 cocok).

-- (c) GUARD: tidak ada baris konsinyasi lain yg ikut berubah (hanya 1 target):
SELECT COUNT(*) AS masih_ada_typo
FROM TSALES1 a JOIN TSALES2 b ON b.BUKTI_ID=a.BUKTI_ID
WHERE a.TIPE_TRANS='22' AND ISNULL(b.EVAP,'')<>'' AND b.EVAP<>b.COND
  AND a.TGL>='2026-01-01';
-- Harapan: 0 (typo satu-satunya sudah beres).


-- ---------- STEP 4: COMMIT / ROLLBACK --------------------------------------
-- COMMIT;     -- jalankan HANYA bila STEP 3 (a)(b)(c) sesuai harapan.
-- ROLLBACK;   -- bila ada yang tidak sesuai.


-- ============================================================================
-- SETELAH COMMIT: jalankan REFRESH periode Juni 2026 (SO/WIP Out/WIP In +
--   transfer konsinyasi ke GL). WIP In faktur ini akan narik otomatis
--   (COND sudah cocok), dan bersama dokumen CARLOSINDO dkk masuk ke GL
--   sehingga Mutasi Stok = Ledger.
--
-- ROLLBACK PASCA-COMMIT (kembalikan typo bila perlu):
--   UPDATE TSALES2 SET COND='64B5DEAC002'
--   WHERE BUKTI_ID='10126062200169' AND URUT=2 AND STOK_ID='NR.201A';
--   COMMIT;
-- ============================================================================
