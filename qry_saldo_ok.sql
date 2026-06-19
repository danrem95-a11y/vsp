/* ============================================================================
   AP AGING / OPNAME HUTANG - SYBASE SQL ANYWHERE 9 COMPATIBLE
   Parameters:
     :arg_tgl1    DATE     -- tanggal awal periode  (misal: '2026-01-01')
     :arg_tgl2    DATE     -- tanggal akhir periode (misal: '2026-01-31')
     '226-001' VARCHAR  -- kode akun GL          (misal: '226-001')

   Fixes applied vs previous version:
     1. PEMBELIAN & PEMBAYARAN: filtered via gl_journal EXISTS so only invoices
        posted to '226-001' are included (removes 226-006 freight cross-talk).
     2. BAYAR_IDR: uses T2.NILAI_BAYAR_IDR (dedicated IDR column) instead of
        T2.NILAI_BAYAR * T1.KURS (which was wrong for multi-currency).
     3. ADJ_IDR: uses TP.NILAI_BAYAR_IDR instead of TP.NILAI_BAYAR * 1.
     4. AWAL_IDR: uses SUM(SALDO_KURS * RATE) -- no hardcoded ratio.
     5. HIST_MUT date range: corrected to year-start via DATEADD/DATEPART.
     6. FLAG_BAYAR: IN (1, 2) covers both pending and confirmed payments.
     7. Hardcoded vendor exclusion removed; GL filter handles account isolation.
   ============================================================================ */

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
    (MAIN.SALDO_AWAL + MAIN.MUTASI + MAIN.ADJ)                                         AS TTL_NETTO,
    (MAIN.SALDO_AWAL_IDR + MAIN.MUTASI_IDR + MAIN.ADJ_IDR)                             AS TTL_NETTO_IDR,
    MAIN.NILAI_BAYAR,
    MAIN.NILAI_BAYAR_IDR,
    (MAIN.SALDO_AWAL + MAIN.MUTASI + MAIN.ADJ - MAIN.NILAI_BAYAR)                      AS SISA,
    (MAIN.SALDO_AWAL_IDR + MAIN.MUTASI_IDR + MAIN.ADJ_IDR - MAIN.NILAI_BAYAR_IDR)      AS SISA_IDR,
    MAIN.VOUCHER_MANUAL,
    MAIN.IS_FIND
FROM
(
    SELECT
        INV.VENDOR_ID                                                          AS CUST_ID,
        ISNULL(SUPP.NAMA, ISNULL(CUST.cust_name, INV.VENDOR_ID))              AS CUST_NAME,
        INV.TGL,
        INV.ORDER_CLIENT,
        INV.BUKTI_REFF,
        INV.CURR_ID,

        /* KURS: freight selalu 1; carry-over pakai SAF.RATE; faktur baru pakai AP_TRANS.KURS */
        ABS(CASE WHEN INV.TIPE_TRANS = '05' THEN 1
                 ELSE ISNULL(
                     CASE WHEN ISNULL(OPN_HIST.RATE, 0) = 0
                              THEN INV.KURS
                          ELSE OPN_HIST.RATE
                     END, 1)
            END)                                                               AS KURS,

        /* NEW_RATE: hanya tampilkan jika revaluasi dilakukan setelah akhir periode */
        ABS(CASE WHEN INV.TIPE_TRANS = '05' THEN 1
                 ELSE CASE WHEN INV.NEW_RATE_TGL >= :arg_tgl2
                                AND INV.NEW_RATE_TGL IS NOT NULL
                               THEN ISNULL(INV.NEW_RATE, 0)
                           ELSE NULL
                      END
            END)                                                               AS NEW_RATE,

        /* ── SALDO AWAL BULAN INI ────────────────────────────────────────────── */
        ISNULL(OPN_HIST.AWAL_KURS,          0)
          + ISNULL(HIST_MUT.PEMBELIAN_LALU,  0)
          + ISNULL(HIST_ADJ.ADJ_LALU,        0)
          - ISNULL(HIST_BYR.BAYAR_LALU,      0)                               AS SALDO_AWAL,

        ISNULL(OPN_HIST.AWAL_IDR,            0)
          + ISNULL(HIST_MUT.PEMBELIAN_LALU_IDR, 0)
          + ISNULL(HIST_ADJ.ADJ_LALU_IDR,    0)
          - ISNULL(HIST_BYR.BAYAR_LALU_IDR,  0)                               AS SALDO_AWAL_IDR,

        /* ── MUTASI BULAN BERJALAN ───────────────────────────────────────────── */
        ISNULL(ALL_MUT.PEMBELIAN_NOW,     0)                                   AS MUTASI,
        ISNULL(ALL_MUT.PEMBELIAN_NOW_IDR, 0)                                   AS MUTASI_IDR,

        /* ── ADJUSTMENT BULAN BERJALAN ──────────────────────────────────────── */
        ISNULL(ALL_ADJ.ADJ_NOW,     0)                                         AS ADJ,
        ISNULL(ALL_ADJ.ADJ_NOW_IDR, 0)                                         AS ADJ_IDR,

        /* ── PEMBAYARAN BULAN BERJALAN ──────────────────────────────────────── */
        ISNULL(ALL_BYR.BAYAR_NOW,     0)                                       AS NILAI_BAYAR,
        ISNULL(ALL_BYR.BAYAR_NOW_IDR, 0)                                       AS NILAI_BAYAR_IDR,
        ALL_BYR.VOUCHER_MANUAL,

        INV.VENDOR_ID + ' '
          + ISNULL(SUPP.NAMA, ISNULL(CUST.cust_name, ''))
          + ' ' + ISNULL(INV.BUKTI_REFF, '')
          + ' ' + ISNULL(INV.CURR_ID, 'IDR')                                  AS IS_FIND

    FROM
    (
        /* ── JANGKAR: satu baris unik per ORDER_CLIENT, hanya akun '226-001' ── */
        SELECT
            JANGKAR.ORDER_CLIENT,
            ISNULL(MAX(A_BASE.TGL),          MAX(SAF.TGL_FAKTUR))             AS TGL,
            ISNULL(MAX(A_BASE.VENDOR_ID),    MAX(SAF.VENDOR_ID))              AS VENDOR_ID,
            ISNULL(MAX(A_BASE.CURR_ID),      MAX(SAF.CURR_ID))                AS CURR_ID,
            ISNULL(MAX(A_BASE.TIPE_TRANS),   CAST(MAX(SAF.TIPE_TRANS) AS VARCHAR(2))) AS TIPE_TRANS,
            ISNULL(MAX(A_BASE.KURS),         MAX(SAF.RATE))                   AS KURS,
            MAX(A_BASE.NEW_RATE)                                               AS NEW_RATE,
            MAX(A_BASE.NEW_RATE_TGL)                                           AS NEW_RATE_TGL,
            ISNULL(MAX(A_BASE.BUKTI_REFF),   MAX(SAF.NO_FAKTUR))              AS BUKTI_REFF
        FROM (
            /* Faktur baru dalam periode berjalan */
            SELECT AT.ORDER_CLIENT
            FROM AP_TRANS AT
            WHERE AT.TIPE_TRANS IN ('02', '05', '06', '12', '16')
              AND AT.TGL >= :arg_tgl1
              AND AT.TGL  < DATEADD(day, 1, :arg_tgl2)
              AND AT.ORDER_CLIENT IN (
                  SELECT GJ.voucher FROM gl_journal GJ
                  WHERE GJ.account_id = '226-001'
                    AND GJ.kredit     > 0)

            UNION

            /* Faktur carry-over dari saldo awal Januari (carry-over dari tahun lalu) */
            SELECT SAF2.BUKTI_ID AS ORDER_CLIENT
            FROM SALDO_AWAL_FAKTUR SAF2
            WHERE SAF2.TIPE_TRANS IN (1, 2)
              AND SAF2.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
              AND SAF2.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1))
              AND SAF2.BUKTI_ID IN (
                  SELECT GJ.voucher FROM gl_journal GJ
                  WHERE GJ.account_id = '226-001'
                    AND GJ.kredit     > 0)

            UNION

            /* Faktur tahun berjalan dari bulan-bulan sebelum periode ini          */
            /* (carry-forward antar bulan dalam tahun yg sama)                     */
            /* Untuk Januari: range Jan1 < Jan1 = kosong → aman, tidak mengubah   */
            /* laporan Januari. Untuk Februari: menangkap faktur Januari yg belum  */
            /* lunas sehingga saldo awal Feb = saldo akhir Jan.                    */
            SELECT AT2.ORDER_CLIENT
            FROM AP_TRANS AT2
            WHERE AT2.TIPE_TRANS IN ('02', '05', '06', '12', '16')
              AND AT2.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
              AND AT2.TGL  < :arg_tgl1
              AND AT2.ORDER_CLIENT IN (
                  SELECT GJ.voucher FROM gl_journal GJ
                  WHERE GJ.account_id = '226-001'
                    AND GJ.kredit     > 0)
        ) JANGKAR
        LEFT JOIN AP_TRANS A_BASE
            ON  A_BASE.ORDER_CLIENT = JANGKAR.ORDER_CLIENT
            AND A_BASE.TIPE_TRANS  IN ('02', '05', '06', '12', '16')
        LEFT JOIN SALDO_AWAL_FAKTUR SAF
            ON  SAF.BUKTI_ID        = JANGKAR.ORDER_CLIENT
            AND SAF.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
            AND SAF.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1))
        GROUP BY JANGKAR.ORDER_CLIENT
    ) INV

    LEFT JOIN MCSTSUPP SUPP ON SUPP.VENDOR_ID = INV.VENDOR_ID
    LEFT JOIN MCUST    CUST ON CUST.cust_id   = INV.VENDOR_ID

    /* ── SA1: Saldo awal tahun dari SALDO_AWAL_FAKTUR ──────────────────────── */
    LEFT JOIN (
        SELECT
            SAF_O.BUKTI_ID,
            AVG(ISNULL(SAF_O.RATE, 0))                    AS RATE,
            SUM(ISNULL(SAF_O.SALDO_KURS, 0))               AS AWAL_KURS,
            SUM(ISNULL(SAF_O.SALDO_KURS * SAF_O.RATE, 0))  AS AWAL_IDR
        FROM SALDO_AWAL_FAKTUR SAF_O
        WHERE SAF_O.TIPE_TRANS IN (1, 2)
          AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
          AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1))
          AND SAF_O.BUKTI_ID IN (
              SELECT GJ.voucher FROM gl_journal GJ
              WHERE GJ.account_id = '226-001'
                AND GJ.kredit     > 0)
        GROUP BY SAF_O.BUKTI_ID
    ) OPN_HIST ON OPN_HIST.BUKTI_ID = INV.ORDER_CLIENT

    /* ── HIST1: Pembelian sebelum periode berjalan (dalam tahun berjalan) ───── */
    LEFT JOIN (
        SELECT
            P.ORDER_CLIENT AS BUKTI_ID,
            SUM(CASE WHEN P.TIPE_TRANS IN ('02', '05', '06', '16') THEN  P.TTL_NETTO
                     WHEN P.TIPE_TRANS = '12'                       THEN -ABS(P.TTL_NETTO)
                     ELSE 0 END)                                    AS PEMBELIAN_LALU,
            SUM(CASE WHEN P.TIPE_TRANS = '05'
                         THEN P.TTL_NETTO
                     ELSE (CASE WHEN P.TIPE_TRANS IN ('02', '06', '16') THEN  P.TTL_NETTO
                                WHEN P.TIPE_TRANS = '12'                THEN -ABS(P.TTL_NETTO)
                                ELSE 0 END) * ISNULL(P.KURS, 1)
                END)                                                AS PEMBELIAN_LALU_IDR
        FROM AP_TRANS P
        WHERE P.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
          AND P.TGL  < :arg_tgl1
          AND P.ORDER_OKE = 'Y'
          AND P.TIPE_TRANS IN ('02', '05', '12', '06', '16')
          AND P.ORDER_CLIENT IN (
              SELECT GJ.voucher FROM gl_journal GJ
              WHERE GJ.account_id = '226-001'
                AND GJ.kredit     > 0)
        GROUP BY P.ORDER_CLIENT
    ) HIST_MUT ON HIST_MUT.BUKTI_ID = INV.ORDER_CLIENT

    /* ── HIST2: Adjustment sebelum periode berjalan (dalam tahun berjalan) ──── */
    LEFT JOIN (
        SELECT
            TP.BUKTI_ID,
            SUM(CASE WHEN TP.FLAG_ORDER NOT IN (2, 22)
                         THEN  ABS(TP.NILAI_BAYAR)
                     ELSE     -ABS(TP.NILAI_BAYAR) END)             AS ADJ_LALU,
            SUM(CASE WHEN TP.FLAG_ORDER NOT IN (2, 22)
                         THEN  ABS(TP.NILAI_BAYAR_IDR)
                     ELSE     -ABS(TP.NILAI_BAYAR_IDR) END)         AS ADJ_LALU_IDR
        FROM TBYR2_PUTIH TP
        WHERE TP.TGL_BAYAR >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
          AND TP.TGL_BAYAR  < :arg_tgl1
          AND TP.BUKTI_ID IN (
              SELECT GJ.voucher FROM gl_journal GJ
              WHERE GJ.account_id = '226-001'
                AND GJ.kredit     > 0)
        GROUP BY TP.BUKTI_ID
    ) HIST_ADJ ON HIST_ADJ.BUKTI_ID = INV.ORDER_CLIENT

    /* ── HIST3: Pembayaran sebelum periode berjalan (dalam tahun berjalan) ──── */
    LEFT JOIN (
        SELECT
            T2.BUKTI_ID,
            SUM(ISNULL(T2.NILAI_BAYAR,     0))  AS BAYAR_LALU,
            SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0))  AS BAYAR_LALU_IDR
        FROM TBYR1 T1
        INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
        WHERE T1.FLAG_BAYAR IN (1, 2)
          AND T1.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
          AND T1.TGL  < :arg_tgl1
          AND T2.BUKTI_ID IN (
              SELECT GJ.voucher FROM gl_journal GJ
              WHERE GJ.account_id = '226-001'
                AND GJ.kredit     > 0)
        GROUP BY T2.BUKTI_ID
    ) HIST_BYR ON HIST_BYR.BUKTI_ID = INV.ORDER_CLIENT

    /* ── MUT: Pembelian periode berjalan ────────────────────────────────────── */
    LEFT JOIN (
        SELECT
            P.ORDER_CLIENT AS BUKTI_ID,
            SUM(CASE WHEN P.TIPE_TRANS IN ('02', '05', '06', '16') THEN  P.TTL_NETTO
                     WHEN P.TIPE_TRANS = '12'                       THEN -ABS(P.TTL_NETTO)
                     ELSE 0 END)                                    AS PEMBELIAN_NOW,
            SUM(CASE WHEN P.TIPE_TRANS = '05'
                         THEN P.TTL_NETTO
                     ELSE (CASE WHEN P.TIPE_TRANS IN ('02', '06', '16') THEN  P.TTL_NETTO
                                WHEN P.TIPE_TRANS = '12'                THEN -ABS(P.TTL_NETTO)
                                ELSE 0 END) * ISNULL(P.KURS, 1)
                END)                                                AS PEMBELIAN_NOW_IDR
        FROM AP_TRANS P
        WHERE P.TGL >= :arg_tgl1
          AND P.TGL  < DATEADD(day, 1, :arg_tgl2)
          AND P.ORDER_OKE = 'Y'
          AND P.TIPE_TRANS IN ('02', '05', '12', '06', '16')
          AND P.ORDER_CLIENT IN (
              SELECT GJ.voucher FROM gl_journal GJ
              WHERE GJ.account_id = '226-001'
                AND GJ.kredit     > 0)
        GROUP BY P.ORDER_CLIENT
    ) ALL_MUT ON ALL_MUT.BUKTI_ID = INV.ORDER_CLIENT

    /* ── ADJ: Adjustment periode berjalan ───────────────────────────────────── */
    LEFT JOIN (
        SELECT
            TP.BUKTI_ID,
            SUM(CASE WHEN TP.FLAG_ORDER NOT IN (2, 22)
                         THEN  ABS(TP.NILAI_BAYAR)
                     ELSE     -ABS(TP.NILAI_BAYAR) END)             AS ADJ_NOW,
            SUM(CASE WHEN TP.FLAG_ORDER NOT IN (2, 22)
                         THEN  ABS(TP.NILAI_BAYAR_IDR)
                     ELSE     -ABS(TP.NILAI_BAYAR_IDR) END)         AS ADJ_NOW_IDR
        FROM TBYR2_PUTIH TP
        WHERE TP.TGL_BAYAR >= :arg_tgl1
          AND TP.TGL_BAYAR  < DATEADD(day, 1, :arg_tgl2)
          AND TP.BUKTI_ID IN (
              SELECT GJ.voucher FROM gl_journal GJ
              WHERE GJ.account_id = '226-001'
                AND GJ.kredit     > 0)
        GROUP BY TP.BUKTI_ID
    ) ALL_ADJ ON ALL_ADJ.BUKTI_ID = INV.ORDER_CLIENT

    /* ── BYR: Pembayaran periode berjalan ───────────────────────────────────── */
    LEFT JOIN (
        SELECT
            T2.BUKTI_ID,
            MAX(T1.VOUCHER_MANUAL)               AS VOUCHER_MANUAL,
            SUM(ISNULL(T2.NILAI_BAYAR,     0))   AS BAYAR_NOW,
            SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0))   AS BAYAR_NOW_IDR
        FROM TBYR1 T1
        INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
        WHERE T1.FLAG_BAYAR IN (1, 2)
          AND T1.TGL >= :arg_tgl1
          AND T1.TGL  < DATEADD(day, 1, :arg_tgl2)
          AND T2.BUKTI_ID IN (
              SELECT GJ.voucher FROM gl_journal GJ
              WHERE GJ.account_id = '226-001'
                AND GJ.kredit     > 0)
        GROUP BY T2.BUKTI_ID
    ) ALL_BYR ON ALL_BYR.BUKTI_ID = INV.ORDER_CLIENT

) MAIN
WHERE
    ROUND((MAIN.SALDO_AWAL + MAIN.MUTASI + MAIN.ADJ - MAIN.NILAI_BAYAR), 2) <> 0
    OR ROUND(MAIN.MUTASI,      2) <> 0
    OR ROUND(MAIN.ADJ,         2) <> 0
    OR ROUND(MAIN.NILAI_BAYAR, 2) <> 0
ORDER BY
    MAIN.CUST_ID,
    MAIN.ORDER_CLIENT;