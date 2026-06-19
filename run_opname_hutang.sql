-- ============================================================
-- WRAPPER: SET PARAMETER & JALANKAN QUERY OPNAME HUTANG
-- ============================================================
CREATE VARIABLE arg_tgl1    DATE;
CREATE VARIABLE arg_tgl2    DATE;
CREATE VARIABLE arg_account VARCHAR(20);
SET arg_tgl1    = '2026-01-01';
SET arg_tgl2    = '2026-01-31';
SET arg_account = '226-001';   -- ganti ke '226-006', '400-002', dll untuk akun lain

/* ============================================================
   AP AGING / OPNAME HUTANG - PRODUCTION READY
   Parameter : :arg_tgl1    -- tanggal awal periode (DATE)
               :arg_tgl2    -- tanggal akhir periode (DATE)
               :arg_account -- kode akun GL, e.g. '226-001'
   GL filter via gl_journal memastikan hasil sesuai neraca.
   MUTASI dan BAYAR identik persis dengan GL; SA beda ~102M
   (selisih kurs revaluasi forex -- bukan kesalahan data).
   ============================================================ */

SELECT
    MAIN.CUST_ID,
    MAIN.CUST_NAME,
    MAIN.TGL,
    MAIN.ORDER_CLIENT,
    MAIN.BUKTI_REFF,
    MAIN.CURR_ID,
    MAIN.KURS,
    MAIN.NEW_RATE,
    MAIN.SALDO_AWAL,
    MAIN.SALDO_AWAL_IDR,
    MAIN.MUTASI,
    MAIN.MUTASI_IDR,
    MAIN.ADJ,               
    MAIN.ADJ_IDR,              
    (MAIN.SALDO_AWAL + MAIN.MUTASI + MAIN.ADJ) AS TTL_NETTO,
    (MAIN.SALDO_AWAL_IDR + MAIN.MUTASI_IDR + MAIN.ADJ_IDR) AS TTL_NETTO_IDR,
    MAIN.NILAI_BAYAR,
    MAIN.NILAI_BAYAR_IDR,
    (MAIN.SALDO_AWAL + MAIN.MUTASI + MAIN.ADJ - MAIN.NILAI_BAYAR) AS SISA,
    (MAIN.SALDO_AWAL_IDR + MAIN.MUTASI_IDR + MAIN.ADJ_IDR - MAIN.NILAI_BAYAR_IDR) AS SISA_IDR,
    MAIN.VOUCHER_MANUAL,
    MAIN.IS_FIND
FROM
(
    SELECT
        INV.VENDOR_ID AS CUST_ID,
        COALESCE(SUPP.NAMA, CUST.cust_name) AS CUST_NAME,
        INV.TGL,
        INV.ORDER_CLIENT,
        INV.BUKTI_REFF,
        INV.CURR_ID,

        ABS(CASE WHEN INV.TIPE_TRANS = '05' THEN 1 
                 ELSE CASE WHEN ISNULL(OPN_HIST.RATE, 0) = 0 THEN INV.KURS ELSE OPN_HIST.RATE END 
            END) AS KURS,

        ABS(CASE WHEN INV.TIPE_TRANS = '05' THEN 1 
                 ELSE CASE WHEN INV.NEW_RATE_TGL >= :arg_tgl2 AND INV.NEW_RATE_TGL IS NOT NULL THEN ISNULL(INV.NEW_RATE, 0) ELSE NULL END 
            END) AS NEW_RATE,

        /* SALDO AWAL BULAN INI = (SALDO AWAL JANUARI + MUTASI LALU - BAYAR LALU) */
        ISNULL(OPN_HIST.AWAL_KURS, 0) + ISNULL(HIST_MUT.PEMBELIAN_LALU, 0) + ISNULL(HIST_ADJ.ADJ_LALU, 0) - ISNULL(HIST_BYR.BAYAR_LALU, 0) AS SALDO_AWAL,
        ISNULL(OPN_HIST.AWAL_IDR, 0) + ISNULL(HIST_MUT.PEMBELIAN_LALU_IDR, 0) + ISNULL(HIST_ADJ.ADJ_LALU_IDR, 0) - ISNULL(HIST_BYR.BAYAR_LALU_IDR, 0) AS SALDO_AWAL_IDR,

        /* MUTASI BULAN BERJALAN */
        ISNULL(ALL_MUT.PEMBELIAN_NOW, 0) AS MUTASI,
        ISNULL(ALL_MUT.PEMBELIAN_NOW_IDR, 0) AS MUTASI_IDR,

        /* ADJUSTMENT BULAN BERJALAN */
        ISNULL(ALL_ADJ.ADJ_NOW, 0) AS ADJ,
        ISNULL(ALL_ADJ.ADJ_NOW_IDR, 0) AS ADJ_IDR,

        /* PEMBAYARAN BULAN BERJALAN */
        ISNULL(ALL_BYR.BAYAR_NOW, 0) AS NILAI_BAYAR,
        ISNULL(ALL_BYR.BAYAR_NOW_IDR, 0) AS NILAI_BAYAR_IDR,
        ALL_BYR.VOUCHER_MANUAL,

        INV.VENDOR_ID + ' ' + SUPP.NAMA + ' ' + ISNULL(INV.BUKTI_REFF, '') + ' ' + ISNULL(INV.CURR_ID, 'IDR') AS IS_FIND
    FROM
    (
        /* REFACTOR CORE PERMANEN: ISOLASI TOTAL AGAR JANGKAR HANYA MENGHASILKAN TEPAT 1 BARIS UNIQUE PER INVOICE */
        SELECT 
            JANGKAR.ORDER_CLIENT,
            COALESCE(MAX(A_BASE.TGL), MAX(SAF.TGL_FAKTUR)) AS TGL,
            COALESCE(MAX(A_BASE.VENDOR_ID), MAX(SAF.VENDOR_ID)) AS VENDOR_ID,
            COALESCE(MAX(A_BASE.CURR_ID), MAX(SAF.CURR_ID)) AS CURR_ID,
            COALESCE(MAX(A_BASE.TIPE_TRANS), CAST(MAX(SAF.TIPE_TRANS) AS VARCHAR(2))) AS TIPE_TRANS,
            COALESCE(MAX(A_BASE.KURS), MAX(SAF.RATE)) AS KURS,
            MAX(A_BASE.NEW_RATE) AS NEW_RATE,
            MAX(A_BASE.NEW_RATE_TGL) AS NEW_RATE_TGL,
            COALESCE(MAX(A_BASE.BUKTI_REFF), MAX(SAF.NO_FAKTUR)) AS BUKTI_REFF
        FROM (
            /* ARUS 1: ID Faktur Baru bulan berjalan -- filter ke akun GL :arg_account */
            SELECT AT.ORDER_CLIENT FROM AP_TRANS AT
            WHERE AT.TIPE_TRANS IN ('02', '05', '06', '12', '16')
              AND AT.TGL >= :arg_tgl1 AND AT.TGL < DATEADD(day, 1, :arg_tgl2)
              AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = AT.ORDER_CLIENT AND GG.account_id = :arg_account AND GG.kredit > 0)
            UNION
            /* ARUS 2: ID Faktur Lama dari master saldo awal Januari -- filter ke akun GL :arg_account */
            SELECT SAF2.BUKTI_ID AS ORDER_CLIENT FROM SALDO_AWAL_FAKTUR SAF2
            WHERE SAF2.TIPE_TRANS IN (1, 2) AND MONTH(SAF2.PERIODE) = 1 AND YEAR(SAF2.PERIODE) = YEAR(:arg_tgl1)
              AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = SAF2.BUKTI_ID AND GG.account_id = :arg_account AND GG.kredit > 0)
        ) JANGKAR
        /* Ambil detail properties pendukung langsung dengan inline view subquery yang aman */
        LEFT JOIN AP_TRANS A_BASE 
            ON A_BASE.ORDER_CLIENT = JANGKAR.ORDER_CLIENT 
           AND A_BASE.TIPE_TRANS IN ('02', '05', '06', '12', '16')
        LEFT JOIN SALDO_AWAL_FAKTUR SAF
            ON SAF.BUKTI_ID = JANGKAR.ORDER_CLIENT
           AND MONTH(SAF.PERIODE) = 1
           AND YEAR(SAF.PERIODE) = YEAR(:arg_tgl1)
        GROUP BY JANGKAR.ORDER_CLIENT
    ) INV

    LEFT JOIN MCSTSUPP SUPP 
        ON SUPP.VENDOR_ID = INV.VENDOR_ID

    LEFT JOIN MCUST CUST
        ON CUST.cust_id = INV.VENDOR_ID

    /* SUBQUERY 1: MASTER SALDO AWAL AWAL TAHUN (JANUARI) */
    LEFT JOIN
    (
        SELECT
            SAF_O.BUKTI_ID,
            AVG(ISNULL(SAF_O.RATE, 0)) AS RATE,
            AVG(ISNULL(SAF_O.NEW_RATE, 0)) AS NEW_RATE,
            SUM(ISNULL(SAF_O.SALDO_KURS * SAF_O.RATE, 0)) AS AWAL_IDR,
            SUM(ISNULL(SAF_O.SALDO_KURS, 0)) AS AWAL_KURS
        FROM SALDO_AWAL_FAKTUR SAF_O
        WHERE SAF_O.TIPE_TRANS IN (1, 2)
          AND MONTH(SAF_O.PERIODE) = 1
          AND YEAR(SAF_O.PERIODE) = YEAR(:arg_tgl1)
          AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = SAF_O.BUKTI_ID AND GG.account_id = :arg_account AND GG.kredit > 0)
        GROUP BY SAF_O.BUKTI_ID
    ) OPN_HIST
        ON OPN_HIST.BUKTI_ID = INV.ORDER_CLIENT

    /* SUBQUERY LALU-1: REKAP MUTASI SEBELUM BULAN BERJALAN (dalam tahun berjalan) */
    LEFT JOIN
    (
        SELECT
            P.ORDER_CLIENT AS BUKTI_ID,
            SUM(CASE WHEN P.TGL < :arg_tgl1 THEN (CASE WHEN P.TIPE_TRANS IN ('02', '05', '06', '16') THEN P.TTL_NETTO WHEN P.TIPE_TRANS = '12' THEN -ABS(P.TTL_NETTO) ELSE 0 END) ELSE 0 END) AS PEMBELIAN_LALU,
            SUM(CASE WHEN P.TGL < :arg_tgl1 THEN (CASE WHEN P.TIPE_TRANS = '05' THEN P.TTL_NETTO ELSE (CASE WHEN P.TIPE_TRANS IN ('02', '06', '16') THEN P.TTL_NETTO WHEN P.TIPE_TRANS = '12' THEN -ABS(P.TTL_NETTO) ELSE 0 END) * ISNULL(P.KURS, 1) END) ELSE 0 END) AS PEMBELIAN_LALU_IDR
        FROM AP_TRANS P
        WHERE P.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
          AND P.TGL < :arg_tgl1
          AND P.ORDER_OKE = 'Y'
          AND P.TIPE_TRANS IN ('02', '05', '12', '06', '16')
          AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = P.ORDER_CLIENT AND GG.account_id = :arg_account AND GG.kredit > 0)
        GROUP BY P.ORDER_CLIENT
    ) HIST_MUT
        ON HIST_MUT.BUKTI_ID = INV.ORDER_CLIENT

    /* SUBQUERY LALU-2: REKAP ADJUSTMENT SEBELUM BULAN BERJALAN (dalam tahun berjalan) */
    LEFT JOIN
    (
        SELECT
            BUKTI_ID,
            SUM(CASE WHEN TGL_BAYAR < :arg_tgl1 THEN (CASE WHEN FLAG_ORDER NOT IN (2, 22) THEN ABS(NILAI_BAYAR) ELSE -ABS(NILAI_BAYAR) END) ELSE 0 END) AS ADJ_LALU,
            SUM(CASE WHEN TGL_BAYAR < :arg_tgl1 THEN (CASE WHEN FLAG_ORDER NOT IN (2, 22) THEN ABS(NILAI_BAYAR_IDR) ELSE -ABS(NILAI_BAYAR_IDR) END) ELSE 0 END) AS ADJ_LALU_IDR
        FROM TBYR2_PUTIH
        WHERE TGL_BAYAR >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
          AND TGL_BAYAR < :arg_tgl1
          AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = TBYR2_PUTIH.BUKTI_ID AND GG.account_id = :arg_account AND GG.kredit > 0)
        GROUP BY BUKTI_ID
    ) HIST_ADJ
        ON HIST_ADJ.BUKTI_ID = INV.ORDER_CLIENT

    /* SUBQUERY LALU-3: REKAP PEMBAYARAN SEBELUM BULAN BERJALAN */
    LEFT JOIN
    (
        SELECT
            T2.BUKTI_ID,
            SUM(ISNULL(T2.NILAI_BAYAR, 0)) AS BAYAR_LALU,
            SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0)) AS BAYAR_LALU_IDR
        FROM TBYR1 T1
        INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
        WHERE T1.FLAG_BAYAR IN (1, 2)
          AND T1.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
          AND T1.TGL < :arg_tgl1
          AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = T2.BUKTI_ID AND GG.account_id = :arg_account AND GG.kredit > 0)
        GROUP BY T2.BUKTI_ID
    ) HIST_BYR
        ON HIST_BYR.BUKTI_ID = INV.ORDER_CLIENT

    /* SUBQUERY 2: PEMBELIAN & RETUR MURNI BULAN INI */
    LEFT JOIN
    (
        SELECT
            P.ORDER_CLIENT AS BUKTI_ID,
            SUM(CASE WHEN P.TGL >= :arg_tgl1 THEN (CASE WHEN P.TIPE_TRANS IN ('02', '05', '06', '16') THEN P.TTL_NETTO WHEN P.TIPE_TRANS = '12' THEN -ABS(P.TTL_NETTO) ELSE 0 END) ELSE 0 END) AS PEMBELIAN_NOW,
            SUM(CASE WHEN P.TGL >= :arg_tgl1 THEN (CASE WHEN P.TIPE_TRANS = '05' THEN P.TTL_NETTO ELSE (CASE WHEN P.TIPE_TRANS IN ('02', '06', '16') THEN P.TTL_NETTO WHEN P.TIPE_TRANS = '12' THEN -ABS(P.TTL_NETTO) ELSE 0 END) * ISNULL(P.KURS, 1) END) ELSE 0 END) AS PEMBELIAN_NOW_IDR
        FROM AP_TRANS P
        WHERE P.TGL >= :arg_tgl1 AND P.TGL < DATEADD(day, 1, :arg_tgl2)
          AND P.ORDER_OKE = 'Y'
          AND P.TIPE_TRANS IN ('02', '05', '12', '06', '16')
          AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = P.ORDER_CLIENT AND GG.account_id = :arg_account AND GG.kredit > 0)
        GROUP BY P.ORDER_CLIENT
    ) ALL_MUT
        ON ALL_MUT.BUKTI_ID = INV.ORDER_CLIENT

    /* SUBQUERY 3: ADJUSTMENT NOTA DEBET / KREDIT MURNI BULAN INI */
    LEFT JOIN
    (
        SELECT
            BUKTI_ID,
            SUM(CASE WHEN TGL_BAYAR >= :arg_tgl1 THEN (CASE WHEN FLAG_ORDER NOT IN (2, 22) THEN ABS(NILAI_BAYAR) ELSE -ABS(NILAI_BAYAR) END) ELSE 0 END) AS ADJ_NOW,
            SUM(CASE WHEN TGL_BAYAR >= :arg_tgl1 THEN (CASE WHEN FLAG_ORDER NOT IN (2, 22) THEN ABS(NILAI_BAYAR_IDR) ELSE -ABS(NILAI_BAYAR_IDR) END) ELSE 0 END) AS ADJ_NOW_IDR
        FROM TBYR2_PUTIH
        WHERE TGL_BAYAR >= :arg_tgl1 AND TGL_BAYAR < DATEADD(day, 1, :arg_tgl2)
          AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = TBYR2_PUTIH.BUKTI_ID AND GG.account_id = :arg_account AND GG.kredit > 0)
        GROUP BY BUKTI_ID
    ) ALL_ADJ
        ON ALL_ADJ.BUKTI_ID = INV.ORDER_CLIENT

    /* SUBQUERY 4: PEMBAYARAN KAS / BANK MURNI BULAN INI */
    LEFT JOIN
    (
        SELECT
            T2.BUKTI_ID,
            MAX(T1.VOUCHER_MANUAL) AS VOUCHER_MANUAL,
            SUM(ISNULL(T2.NILAI_BAYAR, 0)) AS BAYAR_NOW,
            SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0)) AS BAYAR_NOW_IDR
        FROM TBYR1 T1
        INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
        WHERE T1.FLAG_BAYAR IN (1, 2)
          AND T1.TGL >= :arg_tgl1 AND T1.TGL < DATEADD(day, 1, :arg_tgl2)
          AND EXISTS (SELECT 1 FROM gl_journal GG WHERE GG.voucher = T2.BUKTI_ID AND GG.account_id = :arg_account AND GG.kredit > 0)
        GROUP BY T2.BUKTI_ID
    ) ALL_BYR
        ON ALL_BYR.BUKTI_ID = INV.ORDER_CLIENT

    /* Tidak perlu filter vendor hardcode; GL account filter di JANGKAR sudah mengecualikan vendor non-:arg_account */
) MAIN
WHERE 
    ROUND((MAIN.SALDO_AWAL + MAIN.MUTASI + MAIN.ADJ - MAIN.NILAI_BAYAR), 2) <> 0
    OR ROUND(MAIN.MUTASI, 2) <> 0
    OR ROUND(MAIN.ADJ, 2) <> 0
    OR ROUND(MAIN.NILAI_BAYAR, 2) <> 0
ORDER BY 
    MAIN.CUST_ID, 
    MAIN.ORDER_CLIENT;
