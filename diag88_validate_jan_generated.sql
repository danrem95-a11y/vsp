OUTPUT TO 'C:\BTV\debug\diag88_piutang_jan_validate_out.txt' FORMAT ASCII DELIMITED BY '|' QUOTE '';
SELECT
    COUNT(*) AS ROWS,
    CAST(SUM(SALDO_AWAL_IDR) AS DECIMAL(18,2)) AS SA,
    CAST(SUM(MUTASI_IDR) AS DECIMAL(18,2)) AS MU,
    CAST(SUM(ADJ_IDR) AS DECIMAL(18,2)) AS ADJ,
    CAST(SUM(NILAI_BAYAR_IDR) AS DECIMAL(18,2)) AS BYR,
    CAST(SUM(SISA_IDR) AS DECIMAL(18,2)) AS SISA
FROM (
/* ============================================================================
   FIX PERMANENT MASTERPIECE: AR AGING MULTI-MONTH RUNNING BALANCE
   COMPATIBLE: SYBASE SQL ANYWHERE 9 / POWERBUILDER 11.5 DATAWINDOW
   - Januari Tetap Aman & Akurat (Verified)
   - Februari s/d Desember Otomatis Estafet (Saldo Awal Month-N = Saldo Akhir Month-N-1)
   - Tanpa Menggunakan Tabel GL_SUMMARY / Aman dari Error "Table Not Found"
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
    /* ???????????????????????????????????????????????? PART 1: DETAIL FAKTUR SUB-LEDGER ASLI (RUNNING TOTAL MONTHLY) ???????????????????????????????????????????????? */
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
                 WHEN INV.NEW_RATE_TGL >= '2026-01-31' AND INV.NEW_RATE_TGL IS NOT NULL
                     THEN ISNULL(INV.NEW_RATE, 0)
                 ELSE NULL
            END)                                                                       AS NEW_RATE,

                CAST(CASE WHEN MONTH('2026-01-01') = 1 THEN 
                        ISNULL((SELECT SUM(CASE WHEN ISNULL(SAF_O.NEW_SALDO_KURS, 0) <> 0
                                                                                THEN SAF_O.NEW_SALDO_KURS
                                                                        ELSE ISNULL(SAF_O.SALDO_KURS, 0)
                                                             END)
                                        FROM SALDO_AWAL_FAKTUR SAF_O
                                        WHERE SAF_O.BUKTI_ID = INV.ORDER_CLIENT
                                            AND SAF_O.TIPE_TRANS = 1
                                            AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                            AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01'))), 0)
                ELSE 
                        ISNULL((SELECT SUM(CASE WHEN ISNULL(SAF_O.NEW_SALDO_KURS, 0) <> 0
                                                                                THEN SAF_O.NEW_SALDO_KURS
                                                                        ELSE ISNULL(SAF_O.SALDO_KURS, 0)
                                                             END)
                                        FROM SALDO_AWAL_FAKTUR SAF_O
                                        WHERE SAF_O.BUKTI_ID = INV.ORDER_CLIENT
                                            AND SAF_O.TIPE_TRANS = 1
                                            AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                            AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01'))), 0)
                        + ISNULL((SELECT SUM(CASE WHEN AT.CURR_ID IS NOT NULL AND AT.CURR_ID <> 'IDR'
                                                                                    THEN GJ.debet / ISNULL(AT.KURS, 1)
                                                                            ELSE GJ.debet
                                                                 END)
                                            FROM gl_journal GJ
                                            LEFT JOIN AR_TRANS AT
                                                ON AT.ORDER_CLIENT = GJ.voucher
                                             AND AT.TIPE_TRANS IN ('22','32','33','26','36')
                                            WHERE GJ.voucher = INV.ORDER_CLIENT
                                                AND GJ.account_id = '103-001'
                                                AND GJ.debet > 0
                                                AND GJ.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                                AND GJ.TGL < '2026-01-01'), 0)
                        + ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN ABS(TP.NILAI_BAYAR)
                                                                            WHEN TP.FLAG_ORDER = 1 THEN -ABS(TP.NILAI_BAYAR)
                                                                            ELSE 0 END)
                                            FROM TBYR2_PUTIH TP
                                            WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                                                AND TP.TGL_BAYAR >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                                AND TP.TGL_BAYAR < '2026-01-01'
                                                AND TP.FLAG_ORDER IN (1, 11)), 0)
                        - ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR, 0))
                                            FROM TBYR1 T1
                                            INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                                            WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                                                AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                                                AND T1.FLAG_BAYAR IN (1, 2)
                                                AND T1.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                                AND T1.TGL < '2026-01-01'), 0)
                END AS NUMERIC(18,2)) AS SALDO_AWAL,

                CAST(CASE WHEN MONTH('2026-01-01') = 1 THEN 
                        ISNULL((SELECT SUM(ROUND(CASE WHEN ISNULL(SAF_O.NEW_SALDO, 0) <> 0
                                                          THEN SAF_O.NEW_SALDO
                                                      WHEN ISNULL(SAF_O.SALDO, 0) <> 0
                                                          THEN SAF_O.SALDO
                                                      WHEN ISNULL(SAF_O.NEW_RATE, 0) <> 0
                                                          THEN ISNULL(SAF_O.SALDO_KURS, 0) * SAF_O.NEW_RATE
                                                      ELSE ISNULL(SAF_O.SALDO_KURS, 0) * ISNULL(SAF_O.RATE, 1)
                                               END, 2))
                                        FROM SALDO_AWAL_FAKTUR SAF_O
                                        WHERE SAF_O.BUKTI_ID = INV.ORDER_CLIENT
                                            AND SAF_O.TIPE_TRANS = 1
                                            AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                            AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01'))), 0)
                ELSE 
                        ISNULL((SELECT SUM(ROUND(CASE WHEN ISNULL(SAF_O.NEW_SALDO, 0) <> 0
                                                          THEN SAF_O.NEW_SALDO
                                                      WHEN ISNULL(SAF_O.SALDO, 0) <> 0
                                                          THEN SAF_O.SALDO
                                                      WHEN ISNULL(SAF_O.NEW_RATE, 0) <> 0
                                                          THEN ISNULL(SAF_O.SALDO_KURS, 0) * SAF_O.NEW_RATE
                                                      ELSE ISNULL(SAF_O.SALDO_KURS, 0) * ISNULL(SAF_O.RATE, 1)
                                               END, 2))
                                        FROM SALDO_AWAL_FAKTUR SAF_O
                                        WHERE SAF_O.BUKTI_ID = INV.ORDER_CLIENT
                                            AND SAF_O.TIPE_TRANS = 1
                                            AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                            AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01'))), 0)
                        + ISNULL((SELECT SUM(GJ.debet)
                                            FROM gl_journal GJ
                                            WHERE GJ.voucher = INV.ORDER_CLIENT
                                                AND GJ.account_id = '103-001'
                                                AND GJ.debet > 0
                                                AND GJ.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                                AND GJ.TGL < '2026-01-01'), 0)
                        + ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN ABS(TP.NILAI_BAYAR_IDR)
                                                                            WHEN TP.FLAG_ORDER = 1 THEN -ABS(TP.NILAI_BAYAR_IDR)
                                                                            ELSE 0 END)
                                            FROM TBYR2_PUTIH TP
                                            WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                                                AND TP.TGL_BAYAR >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                                AND TP.TGL_BAYAR < '2026-01-01'
                                                AND TP.FLAG_ORDER IN (1, 11)), 0)
                        - ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0))
                                            FROM TBYR1 T1
                                            INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                                            WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                                                AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                                                AND T1.FLAG_BAYAR IN (1, 2)
                                                AND T1.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                                AND T1.TGL < '2026-01-01'), 0)
                END AS NUMERIC(18,2)) AS SALDO_AWAL_IDR,

                ISNULL((SELECT SUM(CASE WHEN AT.CURR_ID IS NOT NULL AND AT.CURR_ID <> 'IDR'
                                                                        THEN GJ.debet / ISNULL(AT.KURS, 1)
                                                                ELSE GJ.debet
                                                     END)
                                FROM gl_journal GJ
                                LEFT JOIN AR_TRANS AT
                                    ON AT.ORDER_CLIENT = GJ.voucher
                                 AND AT.TIPE_TRANS IN ('22','32','33','26','36')
                                WHERE GJ.voucher = INV.ORDER_CLIENT
                                    AND GJ.account_id = '103-001'
                                    AND GJ.debet > 0
                                    AND GJ.TGL >= '2026-01-01'
                                    AND GJ.TGL < DATEADD(day, 1, '2026-01-31')), 0)                 AS MUTASI,
                ISNULL((SELECT SUM(GJ.debet)
                                FROM gl_journal GJ
                                WHERE GJ.voucher = INV.ORDER_CLIENT
                                    AND GJ.account_id = '103-001'
                                    AND GJ.debet > 0
                                    AND GJ.TGL >= '2026-01-01'
                                    AND GJ.TGL < DATEADD(day, 1, '2026-01-31')), 0)                 AS MUTASI_IDR,
                ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN ABS(TP.NILAI_BAYAR)
                                                                WHEN TP.FLAG_ORDER = 1 THEN -ABS(TP.NILAI_BAYAR)
                                                                ELSE 0 END)
                                FROM TBYR2_PUTIH TP
                                WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                                    AND TP.TGL_BAYAR >= '2026-01-01'
                                    AND TP.TGL_BAYAR < DATEADD(day, 1, '2026-01-31')
                                    AND TP.FLAG_ORDER IN (1, 11)), 0)                            AS ADJ,
                ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN ABS(TP.NILAI_BAYAR_IDR)
                                                                WHEN TP.FLAG_ORDER = 1 THEN -ABS(TP.NILAI_BAYAR_IDR)
                                                                ELSE 0 END)
                                FROM TBYR2_PUTIH TP
                                WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                                    AND TP.TGL_BAYAR >= '2026-01-01'
                                    AND TP.TGL_BAYAR < DATEADD(day, 1, '2026-01-31')
                                    AND TP.FLAG_ORDER IN (1, 11)), 0)                            AS ADJ_IDR,
                ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR, 0))
                                FROM TBYR1 T1
                                INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                                WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                                    AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                                    AND T1.FLAG_BAYAR IN (1, 2)
                                    AND T1.TGL >= '2026-01-01'
                                    AND T1.TGL < DATEADD(day, 1, '2026-01-31')), 0)                 AS NILAI_BAYAR,
                ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0))
                                FROM TBYR1 T1
                                INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                                WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                                    AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                                    AND T1.FLAG_BAYAR IN (1, 2)
                                    AND T1.TGL >= '2026-01-01'
                                    AND T1.TGL < DATEADD(day, 1, '2026-01-31')), 0)                 AS NILAI_BAYAR_IDR,
                (SELECT MAX(T1.VOUCHER_MANUAL)
                 FROM TBYR1 T1
                 INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                 WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                     AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                     AND T1.FLAG_BAYAR IN (1, 2)
                     AND T1.TGL >= '2026-01-01'
                     AND T1.TGL < DATEADD(day, 1, '2026-01-31'))                            AS VOUCHER_MANUAL,
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
                            AND AT.TGL >= '2026-01-01'
                            AND AT.TGL < DATEADD(day, 1, '2026-01-31')
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
                            AND SAF2.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                            AND SAF2.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01'))
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
                            AND AT2.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                            AND AT2.TGL < '2026-01-01'
                            AND EXISTS (
                                    SELECT 1
                                    FROM gl_journal GJ
                                    WHERE GJ.voucher = AT2.ORDER_CLIENT
                                        AND GJ.account_id = '103-001'
                                        AND GJ.debet > 0)
        ) GJ_BASE
        LEFT JOIN AR_TRANS A_BASE ON A_BASE.ORDER_CLIENT = GJ_BASE.voucher AND A_BASE.TIPE_TRANS IN ('22','32','33','26','36')
        LEFT JOIN SALDO_AWAL_FAKTUR SAF ON SAF.BUKTI_ID = GJ_BASE.voucher AND SAF.TIPE_TRANS = 1
            AND SAF.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
            AND SAF.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01'))
        GROUP BY GJ_BASE.voucher
    ) INV
    LEFT JOIN MCUST ON MCUST.CUST_ID = INV.CUST_ID

) MAIN
WHERE
    ROUND((MAIN.SALDO_AWAL + MAIN.MUTASI + MAIN.ADJ - MAIN.NILAI_BAYAR), 2) <> 0
    OR ROUND(MAIN.MUTASI,      2) <> 0
    OR ROUND(MAIN.ADJ,         2) <> 0
    OR ROUND(MAIN.NILAI_BAYAR, 2) <> 0
ORDER BY
    MAIN.CUST_ID ASC,
    MAIN.ORDER_CLIENT ASC
) X;

OUTPUT TO 'C:\BTV\debug\diag88_piutang_jan_fx_out.txt' FORMAT ASCII DELIMITED BY '|' QUOTE '';
SELECT
    ORDER_CLIENT,
    CURR_ID,
    CAST(KURS AS DECIMAL(18,2)) AS KURS,
    CAST(ISNULL(NEW_RATE, 0) AS DECIMAL(18,2)) AS NEW_RATE,
    CAST(SALDO_AWAL AS DECIMAL(18,4)) AS SALDO_AWAL,
    CAST(SALDO_AWAL_IDR AS DECIMAL(18,2)) AS SALDO_AWAL_IDR,
    CAST(SISA_IDR AS DECIMAL(18,2)) AS SISA_IDR
FROM (
/* ============================================================================
   FIX PERMANENT MASTERPIECE: AR AGING MULTI-MONTH RUNNING BALANCE
   COMPATIBLE: SYBASE SQL ANYWHERE 9 / POWERBUILDER 11.5 DATAWINDOW
   - Januari Tetap Aman & Akurat (Verified)
   - Februari s/d Desember Otomatis Estafet (Saldo Awal Month-N = Saldo Akhir Month-N-1)
   - Tanpa Menggunakan Tabel GL_SUMMARY / Aman dari Error "Table Not Found"
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
    /* ???????????????????????????????????????????????? PART 1: DETAIL FAKTUR SUB-LEDGER ASLI (RUNNING TOTAL MONTHLY) ???????????????????????????????????????????????? */
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
                 WHEN INV.NEW_RATE_TGL >= '2026-01-31' AND INV.NEW_RATE_TGL IS NOT NULL
                     THEN ISNULL(INV.NEW_RATE, 0)
                 ELSE NULL
            END)                                                                       AS NEW_RATE,

                CAST(CASE WHEN MONTH('2026-01-01') = 1 THEN 
                        ISNULL((SELECT SUM(CASE WHEN ISNULL(SAF_O.NEW_SALDO_KURS, 0) <> 0
                                                                                THEN SAF_O.NEW_SALDO_KURS
                                                                        ELSE ISNULL(SAF_O.SALDO_KURS, 0)
                                                             END)
                                        FROM SALDO_AWAL_FAKTUR SAF_O
                                        WHERE SAF_O.BUKTI_ID = INV.ORDER_CLIENT
                                            AND SAF_O.TIPE_TRANS = 1
                                            AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                            AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01'))), 0)
                ELSE 
                        ISNULL((SELECT SUM(CASE WHEN ISNULL(SAF_O.NEW_SALDO_KURS, 0) <> 0
                                                                                THEN SAF_O.NEW_SALDO_KURS
                                                                        ELSE ISNULL(SAF_O.SALDO_KURS, 0)
                                                             END)
                                        FROM SALDO_AWAL_FAKTUR SAF_O
                                        WHERE SAF_O.BUKTI_ID = INV.ORDER_CLIENT
                                            AND SAF_O.TIPE_TRANS = 1
                                            AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                            AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01'))), 0)
                        + ISNULL((SELECT SUM(CASE WHEN AT.CURR_ID IS NOT NULL AND AT.CURR_ID <> 'IDR'
                                                                                    THEN GJ.debet / ISNULL(AT.KURS, 1)
                                                                            ELSE GJ.debet
                                                                 END)
                                            FROM gl_journal GJ
                                            LEFT JOIN AR_TRANS AT
                                                ON AT.ORDER_CLIENT = GJ.voucher
                                             AND AT.TIPE_TRANS IN ('22','32','33','26','36')
                                            WHERE GJ.voucher = INV.ORDER_CLIENT
                                                AND GJ.account_id = '103-001'
                                                AND GJ.debet > 0
                                                AND GJ.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                                AND GJ.TGL < '2026-01-01'), 0)
                        + ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN ABS(TP.NILAI_BAYAR)
                                                                            WHEN TP.FLAG_ORDER = 1 THEN -ABS(TP.NILAI_BAYAR)
                                                                            ELSE 0 END)
                                            FROM TBYR2_PUTIH TP
                                            WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                                                AND TP.TGL_BAYAR >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                                AND TP.TGL_BAYAR < '2026-01-01'
                                                AND TP.FLAG_ORDER IN (1, 11)), 0)
                        - ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR, 0))
                                            FROM TBYR1 T1
                                            INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                                            WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                                                AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                                                AND T1.FLAG_BAYAR IN (1, 2)
                                                AND T1.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                                AND T1.TGL < '2026-01-01'), 0)
                END AS NUMERIC(18,2)) AS SALDO_AWAL,

                CAST(CASE WHEN MONTH('2026-01-01') = 1 THEN 
                        ISNULL((SELECT SUM(ROUND(CASE WHEN ISNULL(SAF_O.NEW_SALDO, 0) <> 0
                                                          THEN SAF_O.NEW_SALDO
                                                      WHEN ISNULL(SAF_O.SALDO, 0) <> 0
                                                          THEN SAF_O.SALDO
                                                      WHEN ISNULL(SAF_O.NEW_RATE, 0) <> 0
                                                          THEN ISNULL(SAF_O.SALDO_KURS, 0) * SAF_O.NEW_RATE
                                                      ELSE ISNULL(SAF_O.SALDO_KURS, 0) * ISNULL(SAF_O.RATE, 1)
                                               END, 2))
                                        FROM SALDO_AWAL_FAKTUR SAF_O
                                        WHERE SAF_O.BUKTI_ID = INV.ORDER_CLIENT
                                            AND SAF_O.TIPE_TRANS = 1
                                            AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                            AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01'))), 0)
                ELSE 
                        ISNULL((SELECT SUM(ROUND(CASE WHEN ISNULL(SAF_O.NEW_SALDO, 0) <> 0
                                                          THEN SAF_O.NEW_SALDO
                                                      WHEN ISNULL(SAF_O.SALDO, 0) <> 0
                                                          THEN SAF_O.SALDO
                                                      WHEN ISNULL(SAF_O.NEW_RATE, 0) <> 0
                                                          THEN ISNULL(SAF_O.SALDO_KURS, 0) * SAF_O.NEW_RATE
                                                      ELSE ISNULL(SAF_O.SALDO_KURS, 0) * ISNULL(SAF_O.RATE, 1)
                                               END, 2))
                                        FROM SALDO_AWAL_FAKTUR SAF_O
                                        WHERE SAF_O.BUKTI_ID = INV.ORDER_CLIENT
                                            AND SAF_O.TIPE_TRANS = 1
                                            AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                            AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01'))), 0)
                        + ISNULL((SELECT SUM(GJ.debet)
                                            FROM gl_journal GJ
                                            WHERE GJ.voucher = INV.ORDER_CLIENT
                                                AND GJ.account_id = '103-001'
                                                AND GJ.debet > 0
                                                AND GJ.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                                AND GJ.TGL < '2026-01-01'), 0)
                        + ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN ABS(TP.NILAI_BAYAR_IDR)
                                                                            WHEN TP.FLAG_ORDER = 1 THEN -ABS(TP.NILAI_BAYAR_IDR)
                                                                            ELSE 0 END)
                                            FROM TBYR2_PUTIH TP
                                            WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                                                AND TP.TGL_BAYAR >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                                AND TP.TGL_BAYAR < '2026-01-01'
                                                AND TP.FLAG_ORDER IN (1, 11)), 0)
                        - ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0))
                                            FROM TBYR1 T1
                                            INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                                            WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                                                AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                                                AND T1.FLAG_BAYAR IN (1, 2)
                                                AND T1.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                                                AND T1.TGL < '2026-01-01'), 0)
                END AS NUMERIC(18,2)) AS SALDO_AWAL_IDR,

                ISNULL((SELECT SUM(CASE WHEN AT.CURR_ID IS NOT NULL AND AT.CURR_ID <> 'IDR'
                                                                        THEN GJ.debet / ISNULL(AT.KURS, 1)
                                                                ELSE GJ.debet
                                                     END)
                                FROM gl_journal GJ
                                LEFT JOIN AR_TRANS AT
                                    ON AT.ORDER_CLIENT = GJ.voucher
                                 AND AT.TIPE_TRANS IN ('22','32','33','26','36')
                                WHERE GJ.voucher = INV.ORDER_CLIENT
                                    AND GJ.account_id = '103-001'
                                    AND GJ.debet > 0
                                    AND GJ.TGL >= '2026-01-01'
                                    AND GJ.TGL < DATEADD(day, 1, '2026-01-31')), 0)                 AS MUTASI,
                ISNULL((SELECT SUM(GJ.debet)
                                FROM gl_journal GJ
                                WHERE GJ.voucher = INV.ORDER_CLIENT
                                    AND GJ.account_id = '103-001'
                                    AND GJ.debet > 0
                                    AND GJ.TGL >= '2026-01-01'
                                    AND GJ.TGL < DATEADD(day, 1, '2026-01-31')), 0)                 AS MUTASI_IDR,
                ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN ABS(TP.NILAI_BAYAR)
                                                                WHEN TP.FLAG_ORDER = 1 THEN -ABS(TP.NILAI_BAYAR)
                                                                ELSE 0 END)
                                FROM TBYR2_PUTIH TP
                                WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                                    AND TP.TGL_BAYAR >= '2026-01-01'
                                    AND TP.TGL_BAYAR < DATEADD(day, 1, '2026-01-31')
                                    AND TP.FLAG_ORDER IN (1, 11)), 0)                            AS ADJ,
                ISNULL((SELECT SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN ABS(TP.NILAI_BAYAR_IDR)
                                                                WHEN TP.FLAG_ORDER = 1 THEN -ABS(TP.NILAI_BAYAR_IDR)
                                                                ELSE 0 END)
                                FROM TBYR2_PUTIH TP
                                WHERE TP.BUKTI_ID = INV.ORDER_CLIENT
                                    AND TP.TGL_BAYAR >= '2026-01-01'
                                    AND TP.TGL_BAYAR < DATEADD(day, 1, '2026-01-31')
                                    AND TP.FLAG_ORDER IN (1, 11)), 0)                            AS ADJ_IDR,
                ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR, 0))
                                FROM TBYR1 T1
                                INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                                WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                                    AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                                    AND T1.FLAG_BAYAR IN (1, 2)
                                    AND T1.TGL >= '2026-01-01'
                                    AND T1.TGL < DATEADD(day, 1, '2026-01-31')), 0)                 AS NILAI_BAYAR,
                ISNULL((SELECT SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0))
                                FROM TBYR1 T1
                                INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                                WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                                    AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                                    AND T1.FLAG_BAYAR IN (1, 2)
                                    AND T1.TGL >= '2026-01-01'
                                    AND T1.TGL < DATEADD(day, 1, '2026-01-31')), 0)                 AS NILAI_BAYAR_IDR,
                (SELECT MAX(T1.VOUCHER_MANUAL)
                 FROM TBYR1 T1
                 INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                 WHERE T2.BUKTI_ID = INV.ORDER_CLIENT
                     AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                     AND T1.FLAG_BAYAR IN (1, 2)
                     AND T1.TGL >= '2026-01-01'
                     AND T1.TGL < DATEADD(day, 1, '2026-01-31'))                            AS VOUCHER_MANUAL,
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
                            AND AT.TGL >= '2026-01-01'
                            AND AT.TGL < DATEADD(day, 1, '2026-01-31')
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
                            AND SAF2.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                            AND SAF2.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01'))
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
                            AND AT2.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
                            AND AT2.TGL < '2026-01-01'
                            AND EXISTS (
                                    SELECT 1
                                    FROM gl_journal GJ
                                    WHERE GJ.voucher = AT2.ORDER_CLIENT
                                        AND GJ.account_id = '103-001'
                                        AND GJ.debet > 0)
        ) GJ_BASE
        LEFT JOIN AR_TRANS A_BASE ON A_BASE.ORDER_CLIENT = GJ_BASE.voucher AND A_BASE.TIPE_TRANS IN ('22','32','33','26','36')
        LEFT JOIN SALDO_AWAL_FAKTUR SAF ON SAF.BUKTI_ID = GJ_BASE.voucher AND SAF.TIPE_TRANS = 1
            AND SAF.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01')
            AND SAF.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, '2026-01-01'), '2026-01-01'))
        GROUP BY GJ_BASE.voucher
    ) INV
    LEFT JOIN MCUST ON MCUST.CUST_ID = INV.CUST_ID

) MAIN
WHERE
    ROUND((MAIN.SALDO_AWAL + MAIN.MUTASI + MAIN.ADJ - MAIN.NILAI_BAYAR), 2) <> 0
    OR ROUND(MAIN.MUTASI,      2) <> 0
    OR ROUND(MAIN.ADJ,         2) <> 0
    OR ROUND(MAIN.NILAI_BAYAR, 2) <> 0
ORDER BY
    MAIN.CUST_ID ASC,
    MAIN.ORDER_CLIENT ASC
) X
WHERE ORDER_CLIENT IN (
    '101BTB250300036',
    '101BTB250300037',
    '101BTB251100051',
    '101BTB251200030',
    '101BTB251200031',
    '101BTB251200032',
    '101BTB251200035'
)
ORDER BY ORDER_CLIENT;

OUTPUT TO STDOUT;
SELECT 'DIAG88_DONE' AS STATUS;
