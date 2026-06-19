/* ============================================================================
   AR AGING / OPNAME PIUTANG - SYBASE SQL ANYWHERE 9 / POWERBUILDER 11.5 DW
   Parameters:
     :arg_tgl1  DATE  -- tanggal awal periode  (misal: '2026-01-01')
     :arg_tgl2  DATE  -- tanggal akhir periode (misal: '2026-01-31')

   Architecture:
     - Anchor set (UNION 2 sumber) lalu LEFT JOIN ke derived table pre-aggregated
     - Tidak ada CASE WHEN MONTH() branching: rumus ELSE sudah universal
       (untuk Januari, range TGL >= Jan1 AND TGL < Jan1 = kosong, hasil = SAF saja)
     - SAF_IDR priority: NEW_SALDO → SALDO_KURS*NEW_RATE → SALDO
       (menjamin kurs revaluasi akhir tahun selalu terpakai untuk FX invoices)
     - ROUND per SAF row untuk SALDO_AWAL_IDR agar presisi = workbook (ROUND per baris)

   Performance v2 (derived table pre-aggregation, SA9/SA11 compatible - no CTE):
     - 15 scalar correlated subquery diganti 8 derived table pre-agg + LEFT JOIN
       → setiap tabel sumber discan SEKALI saja, bukan N kali per baris invoice
     - EXISTS per baris di anchor diganti INNER JOIN ke DT_GJV (DISTINCT voucher)
       → satu scan gl_journal untuk anchor filter, bukan N correlated seeks
     - 3-branch UNION diringkas ke 2-branch: AR_TRANS branch 1+3 digabung dengan
       range Jan1..arg_tgl2+1 → satu scan AR_TRANS mencakup opening YTD + periode
     - VOUCHER_MANUAL digabung ke BYC (satu scan TBYR1/TBYR2 untuk curr period)
     - Tidak pakai CTE (WITH): kompatibel SA9, SA11, PB 11.5 DataWindow

   Index yang direkomendasikan (jika belum ada):
     CREATE INDEX ix_gj_acct_tgl  ON gl_journal       (account_id, debet, TGL, voucher)
     CREATE INDEX ix_at_tgl_tipe  ON AR_TRANS          (TGL, TIPE_TRANS, ORDER_OKE, ORDER_CLIENT)
     CREATE INDEX ix_at_oc_tipe   ON AR_TRANS          (ORDER_CLIENT, TIPE_TRANS)
     CREATE INDEX ix_saf_periode  ON SALDO_AWAL_FAKTUR (TIPE_TRANS, PERIODE, BUKTI_ID)
     CREATE INDEX ix_tp2p_bukti   ON TBYR2_PUTIH       (BUKTI_ID, FLAG_ORDER, TGL_BAYAR)
     CREATE INDEX ix_tbyr1_tgl    ON TBYR1             (TGL, FLAG_BAYAR, FLAG_VENDOR, VOUCHER)
     CREATE INDEX ix_tbyr2_bukti  ON TBYR2             (BUKTI_ID, VOUCHER)
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
    (MAIN.SALDO_AWAL     + MAIN.MUTASI     + MAIN.ADJ)                                 AS TTL_NETTO,
    (MAIN.SALDO_AWAL_IDR + MAIN.MUTASI_IDR + MAIN.ADJ_IDR)                             AS TTL_NETTO_IDR,
    MAIN.NILAI_BAYAR,
    MAIN.NILAI_BAYAR_IDR,
    (MAIN.SALDO_AWAL     + MAIN.MUTASI     + MAIN.ADJ     - MAIN.NILAI_BAYAR)           AS SISA,
    (MAIN.SALDO_AWAL_IDR + MAIN.MUTASI_IDR + MAIN.ADJ_IDR - MAIN.NILAI_BAYAR_IDR)      AS SISA_IDR,
    MAIN.VOUCHER_MANUAL,
    MAIN.IS_FIND
FROM
(
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
                 WHEN INV.NEW_RATE_TGL >= :arg_tgl2 AND INV.NEW_RATE_TGL IS NOT NULL
                     THEN ISNULL(INV.NEW_RATE, 0)
                 ELSE NULL
            END)                                                                       AS NEW_RATE,

        /* ── SALDO AWAL (VALUTA): SAF opening + GL opening/kurs + TP_OPEN adj - BYR_OPEN ── */
        CAST(
            ISNULL(SOF.saf_saldo_kurs, 0)
            + ISNULL(GJO.debet_sum, 0)
              / CASE WHEN ISNULL(INV.CURR_ID, 'IDR') <> 'IDR' THEN ISNULL(INV.KURS, 1) ELSE 1 END
            + ISNULL(TPO.adj_val,   0)
            - ISNULL(BYO.bayar_val, 0)
        AS NUMERIC(18,2))                                                              AS SALDO_AWAL,

        /* ── SALDO AWAL IDR: SAF IDR + GL opening IDR + TP_OPEN IDR - BYR_OPEN IDR ── */
        /* Priority SAF: NEW_SALDO → SALDO_KURS*NEW_RATE → SALDO  (ROUND per baris)    */
        CAST(
            ISNULL(SOF.saf_saldo_idr, 0)
            + ISNULL(GJO.debet_sum,   0)
            + ISNULL(TPO.adj_idr,     0)
            - ISNULL(BYO.bayar_idr,   0)
        AS NUMERIC(18,2))                                                              AS SALDO_AWAL_IDR,

        /* ── MUTASI (valuta): GL debit periode berjalan / kurs ── */
        ISNULL(GJC.debet_sum, 0)
        / CASE WHEN ISNULL(INV.CURR_ID, 'IDR') <> 'IDR' THEN ISNULL(INV.KURS, 1) ELSE 1 END
                                                                                       AS MUTASI,

        /* ── MUTASI IDR: GL debit periode berjalan ── */
        ISNULL(GJC.debet_sum, 0)                                                       AS MUTASI_IDR,

        /* ── ADJ / ADJ IDR: TBYR2_PUTIH periode berjalan ── */
        ISNULL(TPC.adj_val,  0)                                                        AS ADJ,
        ISNULL(TPC.adj_idr,  0)                                                        AS ADJ_IDR,

        /* ── NILAI BAYAR / NILAI BAYAR IDR: TBYR1/TBYR2 periode berjalan ── */
        ISNULL(BYC.bayar_val,  0)                                                      AS NILAI_BAYAR,
        ISNULL(BYC.bayar_idr,  0)                                                      AS NILAI_BAYAR_IDR,

        BYC.voucher_manual                                                             AS VOUCHER_MANUAL,
        ISNULL(INV.CUST_ID, '') + ' ' + ISNULL(MCUST.CUST_NAME, '') + ' '
            + ISNULL(INV.BUKTI_REFF, '') + ' '
            + ISNULL(INV.CURR_ID, 'IDR')                                               AS IS_FIND
    FROM
    (
        /* INV: anchor voucher set + invoice attributes */
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
            MAX(ISNULL(SAF.RATE,     0))                                       AS SAF_RATE,
            MAX(ISNULL(SAF.NEW_RATE, 0))                                       AS SAF_NEW_RATE,
            MAX(A_BASE.NEW_RATE)                                               AS NEW_RATE,
            MAX(A_BASE.NEW_RATE_TGL)                                           AS NEW_RATE_TGL,
            ISNULL(MAX(A_BASE.BUKTI_REFF), MAX(SAF.NO_FAKTUR))                 AS BUKTI_REFF
        FROM
        (
            /* Branch 1+3 merged: AR_TRANS dari Jan1 tahun ini s/d akhir periode        */
            /* (Jan1..arg_tgl1 = YTD opening; arg_tgl1..arg_tgl2 = periode berjalan)    */
            SELECT AT.ORDER_CLIENT AS voucher
            FROM   AR_TRANS AT
            INNER JOIN (
                SELECT DISTINCT GJX.voucher
                FROM   gl_journal GJX
                WHERE  GJX.account_id = '103-001'
                  AND  GJX.debet > 0
            ) DT_GJV ON DT_GJV.voucher = AT.ORDER_CLIENT
            WHERE  AT.TIPE_TRANS IN ('22','32','33','26','36')
              AND  AT.ORDER_OKE   = 'Y'
              AND  AT.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
              AND  AT.TGL <  DATEADD(day, 1, :arg_tgl2)

            UNION

            /* Branch 2: SAF opening awal tahun */
            SELECT SAF2.BUKTI_ID AS voucher
            FROM   SALDO_AWAL_FAKTUR SAF2
            INNER JOIN (
                SELECT DISTINCT GJX.voucher
                FROM   gl_journal GJX
                WHERE  GJX.account_id = '103-001'
                  AND  GJX.debet > 0
            ) DT_GJV2 ON DT_GJV2.voucher = SAF2.BUKTI_ID
            WHERE  SAF2.TIPE_TRANS = 1
              AND  SAF2.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
              AND  SAF2.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1))
        ) GJ_BASE
        LEFT JOIN AR_TRANS A_BASE ON A_BASE.ORDER_CLIENT = GJ_BASE.voucher
                                 AND A_BASE.TIPE_TRANS IN ('22','32','33','26','36')
        LEFT JOIN SALDO_AWAL_FAKTUR SAF ON SAF.BUKTI_ID  = GJ_BASE.voucher
                                      AND SAF.TIPE_TRANS = 1
                                      AND SAF.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
                                      AND SAF.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1))
        GROUP BY GJ_BASE.voucher
    ) INV

    LEFT JOIN MCUST ON MCUST.CUST_ID = INV.CUST_ID

    /* ── SOF: SAF opening (valuta + IDR), pre-agg per BUKTI_ID ─────────────────────── */
    LEFT JOIN (
        SELECT
            SF.BUKTI_ID,
            SUM(CASE WHEN ISNULL(SF.NEW_SALDO_KURS, 0) <> 0
                         THEN SF.NEW_SALDO_KURS
                     ELSE ISNULL(SF.SALDO_KURS, 0)
                END)                                                           AS saf_saldo_kurs,
            SUM(ROUND(
                CASE WHEN ISNULL(SF.NEW_SALDO,  0) <> 0
                         THEN SF.NEW_SALDO
                     WHEN ISNULL(SF.NEW_RATE,   0) <> 0
                         THEN ISNULL(SF.SALDO_KURS, 0) * SF.NEW_RATE
                     ELSE ISNULL(SF.SALDO, 0)
                END, 2))                                                       AS saf_saldo_idr
        FROM   SALDO_AWAL_FAKTUR SF
        WHERE  SF.TIPE_TRANS = 1
          AND  SF.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
          AND  SF.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1))
        GROUP BY SF.BUKTI_ID
    ) SOF ON SOF.BUKTI_ID = INV.ORDER_CLIENT

    /* ── GJO: GL debit 103-001 periode opening (Jan1 s/d arg_tgl1-1) ───────────────── */
    LEFT JOIN (
        SELECT
            GJ.voucher,
            SUM(GJ.debet) AS debet_sum
        FROM   gl_journal GJ
        WHERE  GJ.account_id = '103-001'
          AND  GJ.debet > 0
          AND  GJ.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
          AND  GJ.TGL <  :arg_tgl1
        GROUP BY GJ.voucher
    ) GJO ON GJO.voucher = INV.ORDER_CLIENT

    /* ── GJC: GL debit 103-001 periode berjalan (arg_tgl1 s/d arg_tgl2) ────────────── */
    LEFT JOIN (
        SELECT
            GJ.voucher,
            SUM(GJ.debet) AS debet_sum
        FROM   gl_journal GJ
        WHERE  GJ.account_id = '103-001'
          AND  GJ.debet > 0
          AND  GJ.TGL >= :arg_tgl1
          AND  GJ.TGL <  DATEADD(day, 1, :arg_tgl2)
        GROUP BY GJ.voucher
    ) GJC ON GJC.voucher = INV.ORDER_CLIENT

    /* ── TPO: TBYR2_PUTIH ADJ periode opening (Jan1 s/d arg_tgl1-1) ───────────────── */
    LEFT JOIN (
        SELECT
            TP.BUKTI_ID,
            SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN  ABS(TP.NILAI_BAYAR)
                     WHEN TP.FLAG_ORDER = 1  THEN -ABS(TP.NILAI_BAYAR)
                     ELSE 0 END)                                               AS adj_val,
            SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN  ABS(TP.NILAI_BAYAR_IDR)
                     WHEN TP.FLAG_ORDER = 1  THEN -ABS(TP.NILAI_BAYAR_IDR)
                     ELSE 0 END)                                               AS adj_idr
        FROM   TBYR2_PUTIH TP
        WHERE  TP.FLAG_ORDER IN (1, 11)
          AND  TP.TGL_BAYAR >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
          AND  TP.TGL_BAYAR <  :arg_tgl1
        GROUP BY TP.BUKTI_ID
    ) TPO ON TPO.BUKTI_ID = INV.ORDER_CLIENT

    /* ── TPC: TBYR2_PUTIH ADJ periode berjalan (arg_tgl1 s/d arg_tgl2) ────────────── */
    LEFT JOIN (
        SELECT
            TP.BUKTI_ID,
            SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN  ABS(TP.NILAI_BAYAR)
                     WHEN TP.FLAG_ORDER = 1  THEN -ABS(TP.NILAI_BAYAR)
                     ELSE 0 END)                                               AS adj_val,
            SUM(CASE WHEN TP.FLAG_ORDER = 11 THEN  ABS(TP.NILAI_BAYAR_IDR)
                     WHEN TP.FLAG_ORDER = 1  THEN -ABS(TP.NILAI_BAYAR_IDR)
                     ELSE 0 END)                                               AS adj_idr
        FROM   TBYR2_PUTIH TP
        WHERE  TP.FLAG_ORDER IN (1, 11)
          AND  TP.TGL_BAYAR >= :arg_tgl1
          AND  TP.TGL_BAYAR <  DATEADD(day, 1, :arg_tgl2)
        GROUP BY TP.BUKTI_ID
    ) TPC ON TPC.BUKTI_ID = INV.ORDER_CLIENT

    /* ── BYO: TBYR1/TBYR2 pembayaran periode opening (Jan1 s/d arg_tgl1-1) ─────────── */
    LEFT JOIN (
        SELECT
            T2.BUKTI_ID,
            SUM(ISNULL(T2.NILAI_BAYAR,     0)) AS bayar_val,
            SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0)) AS bayar_idr
        FROM   TBYR1 T1
        INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
        WHERE  (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
          AND  T1.FLAG_BAYAR IN (1, 2)
          AND  T1.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, :arg_tgl1), :arg_tgl1)
          AND  T1.TGL <  :arg_tgl1
        GROUP BY T2.BUKTI_ID
    ) BYO ON BYO.BUKTI_ID = INV.ORDER_CLIENT

    /* ── BYC: TBYR1/TBYR2 pembayaran periode berjalan (arg_tgl1 s/d arg_tgl2) ──────── */
    LEFT JOIN (
        SELECT
            T2.BUKTI_ID,
            SUM(ISNULL(T2.NILAI_BAYAR,     0)) AS bayar_val,
            SUM(ISNULL(T2.NILAI_BAYAR_IDR, 0)) AS bayar_idr,
            MAX(T1.VOUCHER_MANUAL)              AS voucher_manual
        FROM   TBYR1 T1
        INNER JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
        WHERE  (T1.FLAG_VENDOR = 1 OR T1.FLAG_VENDOR IS NULL)
          AND  T1.FLAG_BAYAR IN (1, 2)
          AND  T1.TGL >= :arg_tgl1
          AND  T1.TGL <  DATEADD(day, 1, :arg_tgl2)
        GROUP BY T2.BUKTI_ID
    ) BYC ON BYC.BUKTI_ID = INV.ORDER_CLIENT

) MAIN
WHERE
    ROUND((MAIN.SALDO_AWAL + MAIN.MUTASI + MAIN.ADJ - MAIN.NILAI_BAYAR), 2) <> 0
    OR ROUND(MAIN.MUTASI,      2) <> 0
    OR ROUND(MAIN.ADJ,         2) <> 0
    OR ROUND(MAIN.NILAI_BAYAR, 2) <> 0
ORDER BY
    MAIN.CUST_ID      ASC,
    MAIN.ORDER_CLIENT ASC;