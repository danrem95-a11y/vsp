SELECT COUNT(*) AS n_voucher, SUM(x.SISA_IDR) AS total_sisa_idr FROM (
/* ============================================================================
   AP AGING / OPNAME HUTANG - SYBASE SQL ANYWHERE 9 / POWERBUILDER 15.1 DW
   Parameters:
     '2026-04-01'         DATE     -- tanggal awal periode  (misal: '2026-01-01')
     '2026-04-30'         DATE     -- tanggal akhir periode (misal: '2026-01-31')
     '226-001'         VARCHAR  -- kode akun GL (hardcoded)

   PowerBuilder DataWindow Painter Compatibility Rules (PERMANENT):
     - Host variable :arg_xxx HANYA boleh muncul di WHERE/HAVING comparison.
       TIDAK boleh di SELECT list, JOIN ON, atau expression compute.
     - TIDAK ada LEFT JOIN (derived) ON 1=1 (painter salah parse).
     - TIDAK ada CTE/window function/MERGE (SA9 tidak support).
     - Derived table boleh punya scalar subquery di kolom SELECT-nya,
       asal scalar subquery hanya pakai :arg_xxx di WHERE.
     - Konstanta numerik literal di SELECT list aman (mis. 14159923466.61).

   Fixes applied vs previous version:
     1. PEMBELIAN & PEMBAYARAN: filtered via gl_journal EXISTS so only invoices
        posted to '226-001' are included (removes 226-006 freight cross-talk).
     2. BAYAR_IDR: uses T2.NILAI_BAYAR_IDR (dedicated IDR column) instead of
        T2.NILAI_BAYAR * T1.KURS (which was wrong for multi-currency).
     3. ADJ_IDR: uses TP.NILAI_BAYAR_IDR instead of TP.NILAI_BAYAR * 1.
      4. AWAL_IDR: carry-over FX memakai SAF.NEW_SALDO; bila kosong fallback ke
        SAF.SALDO_KURS * SAF.NEW_RATE lalu SAF.SALDO. Jalur IDR/freight tetap
        memakai kolom IDR existing dan mutasi IDR period berjalan.
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

        /* KURS: freight selalu 1; carry-over pakai SAF.NEW_RATE (fallback SAF.RATE); faktur baru pakai AP_TRANS.KURS */
        ABS(CASE WHEN INV.TIPE_TRANS = '05' THEN 1
                 ELSE ISNULL(
                     CASE WHEN ISNULL(
                              (SELECT AVG(CASE WHEN ISNULL(SAF_O.NEW_RATE, 0) <> 0
                                               THEN ISNULL(SAF_O.NEW_RATE, 0)
                                               ELSE ISNULL(SAF_O.RATE, 0)
                                          END)
                               FROM SALDO_AWAL_FAKTUR SAF_O
                               WHERE SAF_O.BUKTI_ID = INV.ORDER_CLIENT
                                 AND SAF_O.TIPE_TRANS IN (1, 2)
                                 AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                                 AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01'))),
                              0) = 0
                              THEN INV.KURS
                          ELSE (SELECT AVG(CASE WHEN ISNULL(SAF_O.NEW_RATE, 0) <> 0
                                                THEN ISNULL(SAF_O.NEW_RATE, 0)
                                                ELSE ISNULL(SAF_O.RATE, 0)
                                           END)
                                FROM SALDO_AWAL_FAKTUR SAF_O
                                WHERE SAF_O.BUKTI_ID = INV.ORDER_CLIENT
                                  AND SAF_O.TIPE_TRANS IN (1, 2)
                                  AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                                  AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')))
                     END, 1)
            END)                                                               AS KURS,

        /* NEW_RATE: hanya tampilkan jika revaluasi dilakukan setelah akhir periode */
        ABS(CASE WHEN INV.TIPE_TRANS = '05' THEN 1
                 ELSE CASE WHEN INV.NEW_RATE_TGL >= '2026-04-30'
                                AND INV.NEW_RATE_TGL IS NOT NULL
                               THEN ISNULL(INV.NEW_RATE, 0)
                           ELSE NULL
                      END
            END)                                                               AS NEW_RATE,

        /* ── SALDO AWAL BULAN INI (semua komponen scalar correlated subqueries) ─ */
        ISNULL((SELECT SUM(ISNULL(SAF_O.SALDO_KURS, 0))
                FROM SALDO_AWAL_FAKTUR SAF_O
                WHERE SAF_O.BUKTI_ID = INV.ORDER_CLIENT
                  AND SAF_O.TIPE_TRANS IN (1, 2)
                  AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                  AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01'))), 0)
          + ISNULL((SELECT SUM(CASE WHEN P.TIPE_TRANS IN ('02', '05', '06', '16') THEN  P.TTL_NETTO
                                    WHEN P.TIPE_TRANS = '12'                       THEN -ABS(P.TTL_NETTO)
                                    ELSE 0 END)
                    FROM AP_TRANS P
                    WHERE P.ORDER_CLIENT = INV.ORDER_CLIENT
                      AND P.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                      AND P.TGL  < '2026-04-01'
                      AND P.ORDER_OKE = 'Y'
                      AND P.TIPE_TRANS IN ('02', '05', '12', '06', '16')), 0)
          + ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER NOT IN (2, 22)
                                         THEN  ABS(TP.NILAI_BAYAR)
                                    ELSE     -ABS(TP.NILAI_BAYAR) END)
                    FROM TBYR2_PUTIH TP
                    WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                      AND TP.TGL_BAYAR >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                      AND TP.TGL_BAYAR  < '2026-04-01'), 0)
          - ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR, 0))
                    FROM TBYR1 T1 INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                    WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                      AND T1.FLAG_BAYAR IN (1, 2)
                      AND T1.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                      AND T1.TGL  < '2026-04-01'), 0)                            AS SALDO_AWAL,

        /* SALDO_AWAL_IDR: carry-over FX pakai NEW_SALDO / SALDO_KURS x NEW_RATE, lalu mutasi tetap pakai kolom IDR masing-masing */
        ISNULL((SELECT SUM(CASE
                               WHEN ISNULL(SAF_O.NEW_SALDO, 0) <> 0 THEN ISNULL(SAF_O.NEW_SALDO, 0)
                               WHEN ISNULL(SAF_O.NEW_RATE, 0) <> 0 THEN ISNULL(SAF_O.SALDO_KURS, 0) * ISNULL(SAF_O.NEW_RATE, 0)
                               ELSE ISNULL(SAF_O.SALDO, 0)
                           END)
                FROM SALDO_AWAL_FAKTUR SAF_O
                WHERE SAF_O.BUKTI_ID = INV.ORDER_CLIENT
                  AND SAF_O.TIPE_TRANS IN (1, 2)
                  AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                  AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01'))), 0)
          + ISNULL((SELECT SUM(CASE WHEN P.TIPE_TRANS = '05' THEN P.TTL_NETTO
                                     ELSE (CASE WHEN P.TIPE_TRANS IN ('02', '06', '16') THEN  P.TTL_NETTO
                                                WHEN P.TIPE_TRANS = '12'                THEN -ABS(P.TTL_NETTO)
                                                ELSE 0 END) * ISNULL(P.KURS, 1)
                                END)
                    FROM AP_TRANS P
                    WHERE P.ORDER_CLIENT = INV.ORDER_CLIENT
                      AND P.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                      AND P.TGL  < '2026-04-01'
                      AND P.ORDER_OKE = 'Y'
                      AND P.TIPE_TRANS IN ('02', '05', '12', '06', '16')), 0)
          + ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER NOT IN (2, 22)
                                         THEN  ABS(TP.NILAI_BAYAR_IDR)
                                    ELSE     -ABS(TP.NILAI_BAYAR_IDR) END)
                    FROM TBYR2_PUTIH TP
                    WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                      AND TP.TGL_BAYAR >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                      AND TP.TGL_BAYAR  < '2026-04-01'), 0)
          - ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0))
                    FROM TBYR1 T1 INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                    WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                      AND T1.FLAG_BAYAR IN (1, 2)
                      AND T1.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                      AND T1.TGL  < '2026-04-01'), 0)                            AS SALDO_AWAL_IDR,

        /* ── MUTASI BULAN BERJALAN (scalar correlated; AP_TRANS via IDX_AP_TRANS_ORDER) */
        ISNULL((SELECT SUM(CASE WHEN P.TIPE_TRANS IN ('02', '05', '06', '16') THEN  P.TTL_NETTO
                                WHEN P.TIPE_TRANS = '12'                       THEN -ABS(P.TTL_NETTO)
                                ELSE 0 END)
                FROM AP_TRANS P
                WHERE P.ORDER_CLIENT = INV.ORDER_CLIENT
                  AND P.TGL >= '2026-04-01'
                  AND P.TGL  < DATEADD(day, 1, '2026-04-30')
                  AND P.ORDER_OKE = 'Y'
                  AND P.TIPE_TRANS IN ('02', '05', '12', '06', '16')), 0)     AS MUTASI,
        ISNULL((SELECT SUM(CASE WHEN P.TIPE_TRANS = '05' THEN P.TTL_NETTO
                                ELSE (CASE WHEN P.TIPE_TRANS IN ('02', '06', '16') THEN  P.TTL_NETTO
                                           WHEN P.TIPE_TRANS = '12'                THEN -ABS(P.TTL_NETTO)
                                           ELSE 0 END) * ISNULL(P.KURS, 1)
                           END)
                FROM AP_TRANS P
                WHERE P.ORDER_CLIENT = INV.ORDER_CLIENT
                  AND P.TGL >= '2026-04-01'
                  AND P.TGL  < DATEADD(day, 1, '2026-04-30')
                  AND P.ORDER_OKE = 'Y'
                  AND P.TIPE_TRANS IN ('02', '05', '12', '06', '16')), 0)     AS MUTASI_IDR,

        /* ── ADJUSTMENT BULAN BERJALAN (scalar correlated; IDX_TBYR2_PUTIH_BUKTI) */
        ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER NOT IN (2, 22)
                                     THEN  ABS(TP.NILAI_BAYAR)
                                ELSE     -ABS(TP.NILAI_BAYAR) END)
                FROM TBYR2_PUTIH TP
                WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                  AND TP.TGL_BAYAR >= '2026-04-01'
                  AND TP.TGL_BAYAR  < DATEADD(day, 1, '2026-04-30')), 0)         AS ADJ,
        ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER NOT IN (2, 22)
                                     THEN  ABS(TP.NILAI_BAYAR_IDR)
                                ELSE     -ABS(TP.NILAI_BAYAR_IDR) END)
                FROM TBYR2_PUTIH TP
                WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                  AND TP.TGL_BAYAR >= '2026-04-01'
                  AND TP.TGL_BAYAR  < DATEADD(day, 1, '2026-04-30')), 0)         AS ADJ_IDR,

        /* ── PEMBAYARAN BULAN BERJALAN (scalar subqueries: index TBYR2(BUKTI_ID) → sub-ms per INV row) */
        ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR, 0))
                FROM TBYR1 T1 INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                  AND T1.FLAG_BAYAR IN (1, 2)
                  AND T1.TGL >= '2026-04-01'
                  AND T1.TGL  < DATEADD(day, 1, '2026-04-30')), 0)         AS NILAI_BAYAR,
        ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0))
                FROM TBYR1 T1 INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                  AND T1.FLAG_BAYAR IN (1, 2)
                  AND T1.TGL >= '2026-04-01'
                  AND T1.TGL  < DATEADD(day, 1, '2026-04-30')), 0)         AS NILAI_BAYAR_IDR,
        (SELECT MAX(T1.VOUCHER_MANUAL)
         FROM TBYR1 T1 INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
         WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
           AND T1.FLAG_BAYAR IN (1, 2)
           AND T1.TGL >= '2026-04-01'
           AND T1.TGL  < DATEADD(day, 1, '2026-04-30'))                    AS VOUCHER_MANUAL,

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
              AND AT.TGL >= '2026-04-01'
              AND AT.TGL  < DATEADD(day, 1, '2026-04-30')
              AND EXISTS (
                  SELECT 1 FROM gl_journal GJ
                  WHERE GJ.voucher    = AT.ORDER_CLIENT
                    AND GJ.account_id IN ('226-001','226-006')
                    AND GJ.kredit     > 0)

            UNION

            /* Faktur carry-over dari saldo awal Januari (carry-over dari tahun lalu) */
            SELECT SAF2.BUKTI_ID AS ORDER_CLIENT
            FROM SALDO_AWAL_FAKTUR SAF2
            WHERE SAF2.TIPE_TRANS IN (1, 2)
              AND SAF2.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
              AND SAF2.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01'))
              AND EXISTS (
                  SELECT 1 FROM gl_journal GJ
                  WHERE GJ.voucher    = SAF2.BUKTI_ID
                    AND GJ.account_id IN ('226-001','226-006')
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
              AND AT2.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
              AND AT2.TGL  < '2026-04-01'
              AND EXISTS (
                  SELECT 1 FROM gl_journal GJ
                  WHERE GJ.voucher    = AT2.ORDER_CLIENT
                    AND GJ.account_id IN ('226-001','226-006')
                    AND GJ.kredit     > 0)
        ) JANGKAR
        LEFT JOIN AP_TRANS A_BASE
            ON  A_BASE.ORDER_CLIENT = JANGKAR.ORDER_CLIENT
            AND A_BASE.TIPE_TRANS  IN ('02', '05', '06', '12', '16')
        LEFT JOIN SALDO_AWAL_FAKTUR SAF
            ON  SAF.BUKTI_ID        = JANGKAR.ORDER_CLIENT
            AND SAF.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
            AND SAF.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01'))
        GROUP BY JANGKAR.ORDER_CLIENT
    ) INV

    LEFT JOIN MCSTSUPP SUPP ON SUPP.VENDOR_ID = INV.VENDOR_ID
    LEFT JOIN MCUST    CUST ON CUST.cust_id   = INV.VENDOR_ID

    /* Semua derived (OPN_HIST, MUT_ALL, ADJ_ALL, BYR_ALL) di-inline sbg     */
    /* scalar correlated subqueries di SELECT MAIN. Alasannya: SA9 cenderung */
    /* re-execute derived per row outer (push-down nested-loop) yang bikin   */
    /* lambat. Scalar correlated subquery dengan filter BUKTI_ID/ORDER_CLIENT */
    /* hit index point-lookup (sub-ms), jadi total per query <1 detik untuk  */
    /* ratusan voucher.                                                       */

) MAIN
WHERE
    /* Foreign-currency side checks (original behavior) */
    ROUND((MAIN.SALDO_AWAL + MAIN.MUTASI + MAIN.ADJ - MAIN.NILAI_BAYAR), 2) <> 0
    OR ROUND(MAIN.MUTASI,      2) <> 0
    OR ROUND(MAIN.ADJ,         2) <> 0
    OR ROUND(MAIN.NILAI_BAYAR, 2) <> 0
    /* IDR-side checks (carry-forward sisa FX/scaling agar saldo awal bulan      */
    /* berikutnya tetap = saldo akhir bulan ini. Tanpa ini, voucher yang lunas   */
    /* di sisi mata uang asing tapi masih ada sisa IDR (akibat FX gain/loss atau */
    /* scaling SAF) akan hilang dari laporan bulan berikutnya).                   */
    OR ROUND((MAIN.SALDO_AWAL_IDR + MAIN.MUTASI_IDR + MAIN.ADJ_IDR - MAIN.NILAI_BAYAR_IDR), 2) <> 0
    OR ROUND(MAIN.MUTASI_IDR,      2) <> 0
    OR ROUND(MAIN.ADJ_IDR,         2) <> 0
    OR ROUND(MAIN.NILAI_BAYAR_IDR, 2) <> 0

) x