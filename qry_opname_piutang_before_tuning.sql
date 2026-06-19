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
    /* ──────────────── PART 1: DETAIL FAKTUR SUB-LEDGER ASLI (RUNNING TOTAL MONTHLY) ──────────────── */
    SELECT
        ISNULL(INV.CUST_ID, 'KUST-UNKNOWN')                                            AS CUST_ID,
        ISNULL(MCUST.CUST_NAME, ISNULL(INV.CUST_ID, 'PENYESUAIAN JURNAL MANUAL'))      AS CUST_NAME,
        INV.TGL                                                                        AS TGL,
        INV.ORDER_CLIENT                                                               AS ORDER_CLIENT,
        ISNULL(INV.BUKTI_REFF, INV.ORDER_CLIENT)                                       AS BUKTI_REFF,
        ISNULL(INV.CURR_ID, 'IDR')                                                     AS CURR_ID,
        ISNULL(INV.KURS, 1)                                                            AS KURS,
        ABS(CASE WHEN INV.NEW_RATE_TGL >= :arg_tgl2 AND INV.NEW_RATE_TGL IS NOT NULL THEN ISNULL(INV.NEW_RATE, 0) ELSE NULL END) AS NEW_RATE,

        /* Akumulasi Saldo Awal Berjalan berdasarkan parameter bulan (:arg_tgl1) */
        CAST(CASE WHEN MONTH(:arg_tgl1) = 1 THEN 
            ISNULL(OPN_HIST.AWAL_KURS, 0)
        ELSE 
            ISNULL(OPN_HIST.AWAL_KURS, 0) + ISNULL(HIST_MUT.PIUTANG_LALU, 0) + ISNULL(HIST_ADJ.ADJ_LALU, 0) - ISNULL(HIST_BYR.BAYAR_LALU, 0)
        END AS NUMERIC(18,2)) AS SALDO_AWAL,

        CAST(CASE WHEN MONTH(:arg_tgl1) = 1 THEN 
            ISNULL(OPN_HIST.AWAL_IDR, 0)
        ELSE 
            ISNULL(OPN_HIST.AWAL_IDR, 0) + ISNULL(HIST_MUT.PIUTANG_LALU_IDR, 0) + ISNULL(HIST_ADJ.ADJ_LALU_IDR, 0) - ISNULL(HIST_BYR.BAYAR_LALU_IDR, 0)
        END AS NUMERIC(18,2)) AS SALDO_AWAL_IDR,

        ISNULL(ALL_MUT.PIUTANG_NOW,     0)                                             AS MUTASI,
        ISNULL(ALL_MUT.PIUTANG_NOW_IDR, 0)                                             AS MUTASI_IDR,
        ISNULL(ALL_ADJ.ADJ_NOW,     0)                                                 AS ADJ,
        ISNULL(ALL_ADJ.ADJ_NOW_IDR, 0)                                                 AS ADJ_IDR,
        ISNULL(ALL_BYR.BAYAR_NOW,     0)                                               AS NILAI_BAYAR,
        ISNULL(ALL_BYR.BAYAR_NOW_IDR, 0)                                               AS NILAI_BAYAR_IDR,
        ALL_BYR.VOUCHER_MANUAL,
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
            MAX(A_BASE.NEW_RATE)                                               AS NEW_RATE,
            MAX(A_BASE.NEW_RATE_TGL)                                           AS NEW_RATE_TGL,
            ISNULL(MAX(A_BASE.BUKTI_REFF), MAX(SAF.NO_FAKTUR))                 AS BUKTI_REFF
        FROM (
                        SELECT AT.ORDER_CLIENT AS voucher
                        FROM AR_TRANS AT
                        WHERE AT.TIPE_TRANS IN ('22','32','33','26','36')
                            AND AT.ORDER_OKE = 'Y'
                            AND AT.TGL >= :arg_tgl1
                            AND AT.TGL < DATEADD(day, 1, :arg_tgl2)
                            AND AT.ORDER_CLIENT IN (
                                    SELECT GJ.voucher
                                    FROM gl_journal GJ
                                    WHERE GJ.account_id = '103-001'
                                        AND GJ.debet > 0)

                        UNION

                        SELECT SAF2.BUKTI_ID AS voucher
                        FROM SALDO_AWAL_FAKTUR SAF2
                        WHERE SAF2.TIPE_TRANS = 1
                            AND SAF2.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
                            AND SAF2.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1))
                            AND SAF2.BUKTI_ID IN (
                                    SELECT GJ.voucher
                                    FROM gl_journal GJ
                                    WHERE GJ.account_id = '103-001'
                                        AND GJ.debet > 0)

                        UNION

                        SELECT AT2.ORDER_CLIENT AS voucher
                        FROM AR_TRANS AT2
                        WHERE AT2.TIPE_TRANS IN ('22','32','33','26','36')
                            AND AT2.ORDER_OKE = 'Y'
                            AND AT2.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
                            AND AT2.TGL < :arg_tgl1
                            AND AT2.ORDER_CLIENT IN (
                                    SELECT GJ.voucher
                                    FROM gl_journal GJ
                                    WHERE GJ.account_id = '103-001'
                                        AND GJ.debet > 0)
        ) GJ_BASE
        LEFT JOIN AR_TRANS A_BASE ON A_BASE.ORDER_CLIENT = GJ_BASE.voucher AND A_BASE.TIPE_TRANS IN ('22','32','33','26','36')
        LEFT JOIN SALDO_AWAL_FAKTUR SAF ON SAF.BUKTI_ID = GJ_BASE.voucher AND SAF.TIPE_TRANS = 1
            AND SAF.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
            AND SAF.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1))
        GROUP BY GJ_BASE.voucher
    ) INV
    LEFT JOIN MCUST ON MCUST.CUST_ID = INV.CUST_ID
    LEFT JOIN (
        SELECT
            SAF_O.BUKTI_ID,
            SUM(CASE WHEN ISNULL(SAF_O.NEW_SALDO_KURS, 0) <> 0
                         THEN SAF_O.NEW_SALDO_KURS
                     ELSE ISNULL(SAF_O.SALDO_KURS, 0)
                END) AS AWAL_KURS,
            SUM(CASE WHEN ISNULL(SAF_O.NEW_SALDO, 0) <> 0
                         THEN SAF_O.NEW_SALDO
                     WHEN ISNULL(SAF_O.SALDO, 0) <> 0
                         THEN SAF_O.SALDO
                     WHEN ISNULL(SAF_O.NEW_RATE, 0) <> 0
                         THEN ISNULL(SAF_O.SALDO_KURS, 0) * SAF_O.NEW_RATE
                     ELSE ISNULL(SAF_O.SALDO_KURS, 0) * ISNULL(SAF_O.RATE, 1)
                END) AS AWAL_IDR
        FROM SALDO_AWAL_FAKTUR SAF_O WHERE SAF_O.TIPE_TRANS = 1
          AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
          AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1))
        GROUP BY SAF_O.BUKTI_ID
    ) OPN_HIST ON OPN_HIST.BUKTI_ID = INV.ORDER_CLIENT
    LEFT JOIN (
        SELECT GJ.voucher AS BUKTI_ID, SUM(CASE WHEN AT.CURR_ID IS NOT NULL AND AT.CURR_ID <> 'IDR' THEN GJ.debet / ISNULL(AT.KURS, 1) ELSE GJ.debet END) AS PIUTANG_LALU, SUM(GJ.debet) AS PIUTANG_LALU_IDR
        FROM gl_journal GJ LEFT JOIN AR_TRANS AT ON AT.ORDER_CLIENT = GJ.voucher AND AT.TIPE_TRANS IN ('22','32','33','26','36')
        WHERE MONTH(:arg_tgl1) > 1 AND GJ.account_id = '103-001' AND GJ.debet > 0 AND GJ.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1) AND GJ.TGL < :arg_tgl1 GROUP BY GJ.voucher
    ) HIST_MUT ON HIST_MUT.BUKTI_ID = INV.ORDER_CLIENT
    LEFT JOIN (
        SELECT TP.BUKTI_ID, SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN ABS(TP.NILAI_BAYAR) WHEN TP.FLAG_ORDER = 1 THEN -ABS(TP.NILAI_BAYAR) ELSE 0 END) AS ADJ_LALU, SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN ABS(TP.NILAI_BAYAR_IDR) WHEN TP.FLAG_ORDER = 1 THEN -ABS(TP.NILAI_BAYAR_IDR) ELSE 0 END) AS ADJ_LALU_IDR
        FROM TBYR2_PUTIH TP WHERE MONTH(:arg_tgl1) > 1 AND TP.TGL_BAYAR >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1) AND TP.TGL_BAYAR  < :arg_tgl1 AND TP.FLAG_ORDER IN (1, 11) GROUP BY TP.BUKTI_ID
    ) HIST_ADJ ON HIST_ADJ.BUKTI_ID = INV.ORDER_CLIENT
    LEFT JOIN (
                SELECT T2.BUKTI_ID, SUM(ISNULL(T2.NILAI_BAYAR, 0)) AS BAYAR_LALU, SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0)) AS BAYAR_LALU_IDR
                FROM TBYR1 T1 INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                WHERE MONTH(:arg_tgl1) > 1
                    AND (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                    AND T1.FLAG_BAYAR IN (1, 2)
                    AND T1.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
                    AND T1.TGL < :arg_tgl1
                GROUP BY T2.BUKTI_ID
    ) HIST_BYR ON HIST_BYR.BUKTI_ID = INV.ORDER_CLIENT
    LEFT JOIN (
        SELECT GJ.voucher AS BUKTI_ID, SUM(CASE WHEN AT.CURR_ID IS NOT NULL AND AT.CURR_ID <> 'IDR' THEN GJ.debet / ISNULL(AT.KURS, 1) ELSE GJ.debet END) AS PIUTANG_NOW, SUM(GJ.debet) AS PIUTANG_NOW_IDR
        FROM gl_journal GJ LEFT JOIN AR_TRANS AT ON AT.ORDER_CLIENT = GJ.voucher AND AT.TIPE_TRANS IN ('22','32','33','26','36')
        WHERE GJ.account_id = '103-001' AND GJ.debet > 0 AND GJ.TGL >= :arg_tgl1 AND GJ.TGL < DATEADD(day, 1, :arg_tgl2) GROUP BY GJ.voucher
    ) ALL_MUT ON ALL_MUT.BUKTI_ID = INV.ORDER_CLIENT
    LEFT JOIN (
        SELECT TP.BUKTI_ID, SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN ABS(TP.NILAI_BAYAR) WHEN TP.FLAG_ORDER = 1 THEN -ABS(TP.NILAI_BAYAR) ELSE 0 END) AS ADJ_NOW, SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN ABS(TP.NILAI_BAYAR_IDR) WHEN TP.FLAG_ORDER = 1 THEN -ABS(TP.NILAI_BAYAR_IDR) ELSE 0 END) AS ADJ_NOW_IDR
        FROM TBYR2_PUTIH TP WHERE TP.TGL_BAYAR >= :arg_tgl1 AND TP.TGL_BAYAR  < DATEADD(day, 1, :arg_tgl2) AND TP.FLAG_ORDER IN (1, 11) GROUP BY TP.BUKTI_ID
    ) ALL_ADJ ON ALL_ADJ.BUKTI_ID = INV.ORDER_CLIENT
    LEFT JOIN (
                SELECT T2.BUKTI_ID, MAX(T1.VOUCHER_MANUAL) AS VOUCHER_MANUAL, SUM(ISNULL(T2.NILAI_BAYAR, 0)) AS BAYAR_NOW, SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0)) AS BAYAR_NOW_IDR
                FROM TBYR1 T1 INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
                WHERE (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
                    AND T1.FLAG_BAYAR IN (1, 2)
                    AND T1.TGL >= :arg_tgl1
                    AND T1.TGL < DATEADD(day, 1, :arg_tgl2)
                GROUP BY T2.BUKTI_ID
    ) ALL_BYR ON ALL_BYR.BUKTI_ID = INV.ORDER_CLIENT

) MAIN
WHERE
    ROUND((MAIN.SALDO_AWAL + MAIN.MUTASI + MAIN.ADJ - MAIN.NILAI_BAYAR), 2) <> 0
    OR ROUND(MAIN.MUTASI,      2) <> 0
    OR ROUND(MAIN.ADJ,         2) <> 0
    OR ROUND(MAIN.NILAI_BAYAR, 2) <> 0
ORDER BY
    MAIN.CUST_ID ASC,
    MAIN.ORDER_CLIENT ASC;
