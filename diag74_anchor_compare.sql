SELECT
    CAST((SELECT SUM(CASE WHEN ISNULL(NEW_SALDO,0) <> 0 THEN NEW_SALDO
                          WHEN ISNULL(SALDO,0) <> 0 THEN SALDO
                          WHEN ISNULL(NEW_RATE,0) <> 0 THEN ISNULL(SALDO_KURS,0) * NEW_RATE
                          ELSE ISNULL(SALDO_KURS,0) * ISNULL(RATE,1)
                     END)
          FROM SALDO_AWAL_FAKTUR
          WHERE TIPE_TRANS = 1
            AND PERIODE >= '2026-01-01'
            AND PERIODE < '2026-02-01') AS DECIMAL(18,2)) AS ALL_SAF,
    CAST((SELECT SUM(CASE WHEN ISNULL(SAF.NEW_SALDO,0) <> 0 THEN SAF.NEW_SALDO
                          WHEN ISNULL(SAF.SALDO,0) <> 0 THEN SAF.SALDO
                          WHEN ISNULL(SAF.NEW_RATE,0) <> 0 THEN ISNULL(SAF.SALDO_KURS,0) * SAF.NEW_RATE
                          ELSE ISNULL(SAF.SALDO_KURS,0) * ISNULL(SAF.RATE,1)
                     END)
          FROM SALDO_AWAL_FAKTUR SAF
          WHERE SAF.TIPE_TRANS = 1
            AND SAF.PERIODE >= '2026-01-01'
            AND SAF.PERIODE < '2026-02-01'
            AND SAF.BUKTI_ID IN (
                SELECT DISTINCT GJ.voucher
                FROM gl_journal GJ
                WHERE GJ.account_id = '103-001'
                  AND GJ.debet > 0
            )) AS DECIMAL(18,2)) AS GL_ANCHORED,
    CAST(
        (SELECT SUM(CASE WHEN ISNULL(NEW_SALDO,0) <> 0 THEN NEW_SALDO
                         WHEN ISNULL(SALDO,0) <> 0 THEN SALDO
                         WHEN ISNULL(NEW_RATE,0) <> 0 THEN ISNULL(SALDO_KURS,0) * NEW_RATE
                         ELSE ISNULL(SALDO_KURS,0) * ISNULL(RATE,1)
                    END)
         FROM SALDO_AWAL_FAKTUR
         WHERE TIPE_TRANS = 1
           AND PERIODE >= '2026-01-01'
           AND PERIODE < '2026-02-01')
        -
        (SELECT SUM(CASE WHEN ISNULL(SAF.NEW_SALDO,0) <> 0 THEN SAF.NEW_SALDO
                         WHEN ISNULL(SAF.SALDO,0) <> 0 THEN SAF.SALDO
                         WHEN ISNULL(SAF.NEW_RATE,0) <> 0 THEN ISNULL(SAF.SALDO_KURS,0) * SAF.NEW_RATE
                         ELSE ISNULL(SAF.SALDO_KURS,0) * ISNULL(SAF.RATE,1)
                    END)
         FROM SALDO_AWAL_FAKTUR SAF
         WHERE SAF.TIPE_TRANS = 1
           AND SAF.PERIODE >= '2026-01-01'
           AND SAF.PERIODE < '2026-02-01'
           AND SAF.BUKTI_ID IN (
               SELECT DISTINCT GJ.voucher
               FROM gl_journal GJ
               WHERE GJ.account_id = '103-001'
                 AND GJ.debet > 0
           ))
    AS DECIMAL(18,2)) AS DIFF_IDR;
