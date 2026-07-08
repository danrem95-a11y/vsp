SELECT COUNT(*) AS n_voucher, SUM(x.SISA_IDR) AS total_sisa_idr FROM (
/* ============================================================================
   AR AGING / OPNAME PIUTANG - SYBASE SQL ANYWHERE 9 / POWERBUILDER 11.5 DW
   Parameters:
     '2026-04-01'  DATE  -- tanggal awal periode  (misal: '2026-01-01')
     '2026-04-30'  DATE  -- tanggal akhir periode (misal: '2026-01-31')

   Architecture (sama seperti qryopname_ap.sql):
     - Anchor set (UNION 3 sumber) lalu scalar correlated subquery per voucher
     - Tidak ada CASE WHEN MONTH() branching: rumus ELSE sudah universal
       (untuk Januari, range TGL >= Jan1 AND TGL < Jan1 = kosong, hasil = SAF saja)
     - SAF_IDR priority: NEW_SALDO → SALDO_KURS*NEW_RATE → SALDO
       (menjamin kurs revaluasi akhir tahun selalu terpakai untuk FX invoices)
     - ROUND per SAF row untuk SALDO_AWAL_IDR agar presisi = workbook (ROUND per baris)

   Fixes vs previous version:
     1. Removed MONTH('2026-04-01')=1 branch — ELSE already handles January correctly
     2. SAF_IDR priority fixed: dropped intermediate SALDO check before NEW_RATE
        Old: NEW_SALDO → SALDO → SALDO_KURS*NEW_RATE  ← WRONG (SALDO=old rate blocks revaluation)
        New: NEW_SALDO → SALDO_KURS*NEW_RATE → SALDO   ← CORRECT (matches qryopname_ap)
     3. KURS/NEW_RATE columns: SAF.NEW_RATE prioritised for FX carry-over invoices
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
    /* ──────────────── PART 1: DETAIL FAKTUR SUB-LEDGER ASLI (RUNNING TOTAL MONTHLY) ──────────────── */
    SELECT
        ISNULL(INV.CUST_ID, 'KUST-UNKNOWN')                                            AS CUST_ID,
        ISNULL(MCUST.CUST_NAME, ISNULL(INV.CUST_ID, 'PENYESUAIAN JURNAL MANUAL'))      AS CUST_NAME,
        INV.TGL                                                                        AS TGL,
        INV.ORDER_CLIENT                                                               AS ORDER_CLIENT,
        ISNULL(INV.BUKTI_REFF, INV.ORDER_CLIENT)                                       AS BUKTI_REFF,
        ISNULL(INV.CURR_ID, 'IDR')                                                     AS CURR_ID,
        ABS(CASE WHEN ISNULL(INV.SAF_NEW_RATE, 0) <> 0 AND ISNULL(INV.CURR_ID, 'IDR') <> 'IDR'
                     THEN INV.SAF_NEW_RATE
                 ELSE ISNULL(INV.KURS, 1)
            END)                                                                       AS KURS,
        ABS(CASE WHEN ISNULL(INV.SAF_NEW_RATE, 0) <> 0 AND ISNULL(INV.CURR_ID, 'IDR') <> 'IDR'
                     THEN INV.SAF_NEW_RATE
                 WHEN INV.NEW_RATE_TGL >= '2026-04-30' AND INV.NEW_RATE_TGL IS NOT NULL
                     THEN ISNULL(INV.NEW_RATE, 0)
                 ELSE NULL
            END)                                                                       AS NEW_RATE,

                /* ── SALDO AWAL (VALUTA): SAF opening + mutasi YTD sebelum periode ── */
                CAST(
                        ISNULL((SELECT SUM(CASE WHEN ISNULL(SAF_O.NEW_SALDO_KURS, 0) <> 0
                                                    THEN SAF_O.NEW_SALDO_KURS
                                                ELSE ISNULL(SAF_O.SALDO_KURS, 0)
                                           END)
                                FROM SALDO_AWAL_FAKTUR SAF_O
                                WHERE SAF_O.BUKTI_ID = INV.ORDER_CLIENT
                                    AND SAF_O.TIPE_TRANS = 1
                                    AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                                    AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01'))), 0)
                        + ISNULL(
                              (SELECT SUM(GJ.debet)
                               FROM gl_journal GJ
                               WHERE GJ.voucher = INV.ORDER_CLIENT
                                   AND GJ.account_id = '103-001'
                                   AND GJ.debet > 0
                                   AND GJ.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                                   AND GJ.TGL < '2026-04-01')
                              / CASE WHEN ISNULL(INV.CURR_ID, 'IDR') <> 'IDR' THEN ISNULL(INV.KURS, 1) ELSE 1 END,
                          0)
                        + ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN  ABS(TP.NILAI_BAYAR)
                                                  WHEN TP.FLAG_ORDER = 1  THEN -ABS(TP.NILAI_BAYAR)
                                                  ELSE 0 END)
                                  FROM TBYR2_PUTIH TP
                                  WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                                      AND TP.TGL_BAYAR >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                                      AND TP.TGL_BAYAR <  '2026-04-01'
                                      AND TP.FLAG_ORDER IN (1, 11)), 0)
                        - ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR, 0))
                                  FROM TBYR1 T1
                                  INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                                  WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                                      AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                                      AND T1.FLAG_BAYAR IN (1, 2)
                                      AND T1.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                                      AND T1.TGL < '2026-04-01'), 0)
                AS NUMERIC(18,2))                                                          AS SALDO_AWAL,

                /* ── SALDO AWAL IDR: SAF IDR (kurs revaluasi utama) + mutasi IDR YTD ── */
                /* Priority: NEW_SALDO → SALDO_KURS*NEW_RATE → SALDO                      */
                /* ROUND per baris SAF agar presisi = workbook OPNAME FAKTUR PIUTANG       */
                CAST(
                        ISNULL((SELECT SUM(ROUND(CASE WHEN ISNULL(SAF_O.NEW_SALDO, 0) <> 0
                                                          THEN SAF_O.NEW_SALDO
                                                      WHEN ISNULL(SAF_O.NEW_RATE, 0) <> 0
                                                          THEN ISNULL(SAF_O.SALDO_KURS, 0) * SAF_O.NEW_RATE
                                                      ELSE ISNULL(SAF_O.SALDO, 0)
                                               END, 2))
                                FROM SALDO_AWAL_FAKTUR SAF_O
                                WHERE SAF_O.BUKTI_ID = INV.ORDER_CLIENT
                                    AND SAF_O.TIPE_TRANS = 1
                                    AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                                    AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01'))), 0)
                        + ISNULL((SELECT SUM(GJ.debet)
                                  FROM gl_journal GJ
                                  WHERE GJ.voucher = INV.ORDER_CLIENT
                                      AND GJ.account_id = '103-001'
                                      AND GJ.debet > 0
                                      AND GJ.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                                      AND GJ.TGL < '2026-04-01'), 0)
                        + ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN  ABS(TP.NILAI_BAYAR_IDR)
                                                  WHEN TP.FLAG_ORDER = 1  THEN -ABS(TP.NILAI_BAYAR_IDR)
                                                  ELSE 0 END)
                                  FROM TBYR2_PUTIH TP
                                  WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                                      AND TP.TGL_BAYAR >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                                      AND TP.TGL_BAYAR <  '2026-04-01'
                                      AND TP.FLAG_ORDER IN (1, 11)), 0)
                        - ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0))
                                  FROM TBYR1 T1
                                  INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                                  WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                                      AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                                      AND T1.FLAG_BAYAR IN (1, 2)
                                      AND T1.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                                      AND T1.TGL < '2026-04-01'), 0)
                AS NUMERIC(18,2))                                                          AS SALDO_AWAL_IDR,

                ISNULL(
                    (SELECT SUM(GJ.debet)
                     FROM gl_journal GJ
                     WHERE GJ.voucher = INV.ORDER_CLIENT
                         AND GJ.account_id = '103-001'
                         AND GJ.debet > 0
                         AND GJ.TGL >= '2026-04-01'
                         AND GJ.TGL < DATEADD(day, 1, '2026-04-30'))
                    / CASE WHEN ISNULL(INV.CURR_ID, 'IDR') <> 'IDR' THEN ISNULL(INV.KURS, 1) ELSE 1 END,
                  0)                                                                              AS MUTASI,
                ISNULL((SELECT SUM(GJ.debet)
                                FROM gl_journal GJ
                                WHERE GJ.voucher = INV.ORDER_CLIENT
                                    AND GJ.account_id = '103-001'
                                    AND GJ.debet > 0
                                    AND GJ.TGL >= '2026-04-01'
                                    AND GJ.TGL < DATEADD(day, 1, '2026-04-30')), 0)                 AS MUTASI_IDR,
                ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN ABS(TP.NILAI_BAYAR)
                                                                WHEN TP.FLAG_ORDER = 1 THEN -ABS(TP.NILAI_BAYAR)
                                                                ELSE 0 END)
                                FROM TBYR2_PUTIH TP
                                WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                                    AND TP.TGL_BAYAR >= '2026-04-01'
                                    AND TP.TGL_BAYAR < DATEADD(day, 1, '2026-04-30')
                                    AND TP.FLAG_ORDER IN (1, 11)), 0)                            AS ADJ,
                ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN ABS(TP.NILAI_BAYAR_IDR)
                                                                WHEN TP.FLAG_ORDER = 1 THEN -ABS(TP.NILAI_BAYAR_IDR)
                                                                ELSE 0 END)
                                FROM TBYR2_PUTIH TP
                                WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                                    AND TP.TGL_BAYAR >= '2026-04-01'
                                    AND TP.TGL_BAYAR < DATEADD(day, 1, '2026-04-30')
                                    AND TP.FLAG_ORDER IN (1, 11)), 0)                            AS ADJ_IDR,
                ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR, 0))
                                FROM TBYR1 T1
                                INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                                WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                                    AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                                    AND T1.FLAG_BAYAR IN (1, 2)
                                    AND T1.TGL >= '2026-04-01'
                                    AND T1.TGL < DATEADD(day, 1, '2026-04-30')), 0)                 AS NILAI_BAYAR,
                ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0))
                                FROM TBYR1 T1
                                INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                                WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                                    AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                                    AND T1.FLAG_BAYAR IN (1, 2)
                                    AND T1.TGL >= '2026-04-01'
                                    AND T1.TGL < DATEADD(day, 1, '2026-04-30')), 0)                 AS NILAI_BAYAR_IDR,
                (SELECT MAX(T1.VOUCHER_MANUAL)
                 FROM TBYR1 T1
                 INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                 WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                     AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                     AND T1.FLAG_BAYAR IN (1, 2)
                     AND T1.TGL >= '2026-04-01'
                     AND T1.TGL < DATEADD(day, 1, '2026-04-30'))                            AS VOUCHER_MANUAL,
        ISNULL(INV.CUST_ID, '') + ' ' + ISNULL(MCUST.CUST_NAME, '') + ' ' + ISNULL(INV.BUKTI_REFF, '') + ' ' + ISNULL(INV.CURR_ID, 'IDR') AS IS_FIND
    FROM
    (
        SELECT
            GJ_BASE.voucher                                                    AS ORDER_CLIENT,
            ISNULL(MAX(A_BASE.TGL), MAX(SAF.TGL_FAKTUR))                       AS TGL,
            ISNULL(MAX(A_BASE.CUST_ID), MAX(SAF.VENDOR_ID))                    AS CUST_ID,
            ISNULL(MAX(A_BASE.CURR_ID), ISNULL(MAX(SAF.CURR_ID), 'IDR'))       AS CURR_ID,
            ISNULL(MAX(A_BASE.KURS),
                   CASE WHEN MAX(ISNULL(SAF.NEW_RATE, 0)) <> 0
                            THEN MAX(SAF.NEW_RATE)
                        ELSE ISNULL(MAX(SAF.RATE), 1)
                   END)                                                        AS KURS,
                 MAX(ISNULL(SAF.RATE, 0))                                           AS SAF_RATE,
                 MAX(ISNULL(SAF.NEW_RATE, 0))                                       AS SAF_NEW_RATE,
            MAX(A_BASE.NEW_RATE)                                               AS NEW_RATE,
            MAX(A_BASE.NEW_RATE_TGL)                                           AS NEW_RATE_TGL,
            ISNULL(MAX(A_BASE.BUKTI_REFF), MAX(SAF.NO_FAKTUR))                 AS BUKTI_REFF
        FROM (
                        SELECT AT.ORDER_CLIENT AS voucher
                        FROM AR_TRANS AT
                        WHERE AT.TIPE_TRANS IN ('22','32','33','26','36')
                            AND AT.ORDER_OKE = 'Y'
                            AND AT.TGL >= '2026-04-01'
                            AND AT.TGL < DATEADD(day, 1, '2026-04-30')
                            AND EXISTS (
                                    SELECT 1
                                    FROM gl_journal GJ
                                    WHERE GJ.voucher = AT.ORDER_CLIENT
                                        AND GJ.account_id = '103-001'
                                        AND GJ.debet > 0)

                        UNION

                        SELECT SAF2.BUKTI_ID AS voucher
                        FROM SALDO_AWAL_FAKTUR SAF2
                        WHERE SAF2.TIPE_TRANS = 1
                            AND SAF2.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                            AND SAF2.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01'))
                            AND EXISTS (
                                    SELECT 1
                                    FROM gl_journal GJ
                                    WHERE GJ.voucher = SAF2.BUKTI_ID
                                        AND GJ.account_id = '103-001'
                                        AND GJ.debet > 0)

                        UNION

                        SELECT AT2.ORDER_CLIENT AS voucher
                        FROM AR_TRANS AT2
                        WHERE AT2.TIPE_TRANS IN ('22','32','33','26','36')
                            AND AT2.ORDER_OKE = 'Y'
                            AND AT2.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
                            AND AT2.TGL < '2026-04-01'
                            AND EXISTS (
                                    SELECT 1
                                    FROM gl_journal GJ
                                    WHERE GJ.voucher = AT2.ORDER_CLIENT
                                        AND GJ.account_id = '103-001'
                                        AND GJ.debet > 0)
        ) GJ_BASE
        LEFT JOIN AR_TRANS A_BASE ON A_BASE.ORDER_CLIENT = GJ_BASE.voucher AND A_BASE.TIPE_TRANS IN ('22','32','33','26','36')
        LEFT JOIN SALDO_AWAL_FAKTUR SAF ON SAF.BUKTI_ID = GJ_BASE.voucher AND SAF.TIPE_TRANS = 1
            AND SAF.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01')
            AND SAF.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-04-01'), '2026-04-01'))
        GROUP BY GJ_BASE.voucher
    ) INV
    LEFT JOIN MCUST ON MCUST.CUST_ID = INV.CUST_ID

) MAIN
WHERE
    ROUND((MAIN.SALDO_AWAL + MAIN.MUTASI + MAIN.ADJ - MAIN.NILAI_BAYAR), 2) <> 0
    OR ROUND(MAIN.MUTASI,      2) <> 0
    OR ROUND(MAIN.ADJ,         2) <> 0
    OR ROUND(MAIN.NILAI_BAYAR, 2) <> 0

) x