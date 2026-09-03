-- ============================================================
-- ACCEPTANCE_crossperiod.sql — uji requirement bisnis UTAMA (EC4 + B3/B5)
--   Serial: WIP-Out bulan awal (mis. Jan) -> Jual bulan akhir (mis. Jul).
--   Uji: REFRESH BULAN JUAL SAJA. Harapan:
--        (1) HPP & GL WIP-Out bulan AWAL TIDAK berubah (immutable, no backward-prop).
--        (2) HPP penjualan bulan akhir = HPP WIP-Out bulan awal (beku).
-- ============================================================

-- ---------- STEP 0 : FINDER — pilih serial kandidat (WIP-Out < Jual, beda bulan) ----------
SELECT o.evap, o.stok_id,
       CAST(o.tgl_out AS DATE) tgl_wipout, CAST(o.hpp_out AS NUMERIC(18,2)) hpp_wipout,
       CAST(s.tgl_sale AS DATE) tgl_jual, s.bukti_sale
FROM (SELECT s2.evap, s2.stok_id, s1.tgl tgl_out, s2.hpp hpp_out
      FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
      WHERE s1.tipe_trans='88' AND ISNULL(s2.evap,'')<>'' AND ISNULL(s2.hpp,0)>0) o
JOIN (SELECT s2.evap, s1.tgl tgl_sale, s1.bukti_id bukti_sale
      FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
      WHERE s1.tipe_trans='22' AND ISNULL(s2.evap,'')<>'') s
  ON s.evap=o.evap AND s.tgl_sale > o.tgl_out
     AND (year(s.tgl_sale)*100+month(s.tgl_sale)) <> (year(o.tgl_out)*100+month(o.tgl_out))
ORDER BY o.tgl_out, o.evap;
-- >>> Catat 1 serial dari hasil (mis. evap='CIM1096180'), lalu ganti :SER di bawah.

-- ---------- STEP 1 : SNAPSHOT bulan AWAL (SEBELUM refresh bulan jual) ----------
CREATE TABLE _snap_xper (item varchar(30), kunci varchar(30), nilai double, PRIMARY KEY(item,kunci));
DELETE FROM _snap_xper; COMMIT;

-- 1a: HPP WIP-Out ('88') serial ybs
INSERT INTO _snap_xper
SELECT 'wipout_hpp', s2.evap, s2.hpp
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
WHERE s1.tipe_trans='88' AND s2.evap='CIM1096180';        -- <<< ganti :SER

-- 1b: GL 102-020 (debet WIP-Out) voucher '88' serial ybs
INSERT INTO _snap_xper
SELECT 'gl_102020', g.voucher, SUM(g.debet)
FROM gl_journal g
WHERE g.modul_id='AS' AND g.account_id='102-020'
  AND g.voucher IN (SELECT s1.order_client FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
                    WHERE s1.tipe_trans='88' AND s2.evap='CIM1096180')   -- <<< ganti :SER
GROUP BY g.voucher;
COMMIT;
SELECT * FROM _snap_xper ORDER BY item,kunci;

-- ---------- STEP 2 : (APLIKASI) REFRESH BULAN JUAL SAJA (mis. Juli), JANGAN refresh bln awal ----------

-- ---------- STEP 3 : VERIFIKASI ----------
-- 3a: HPP WIP-Out bln awal TIDAK berubah  (harapan: selisih=0)
SELECT 'B5 immutable WIP-Out' uji, s2.evap,
       CAST(sn.nilai AS NUMERIC(18,2)) hpp_sebelum,
       CAST(s2.hpp   AS NUMERIC(18,2)) hpp_sesudah,
       CAST(s2.hpp - sn.nilai AS NUMERIC(18,2)) selisih,
       (CASE WHEN ABS(s2.hpp-sn.nilai)<=0.01 THEN 'LULUS' ELSE 'GAGAL' END) status
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
JOIN _snap_xper sn ON sn.item='wipout_hpp' AND sn.kunci=s2.evap
WHERE s1.tipe_trans='88' AND s2.evap='CIM1096180';        -- <<< ganti :SER

-- 3b: GL 102-020 WIP-Out bln awal TIDAK berubah  (harapan: selisih=0)
SELECT 'B5 immutable GL WIP-Out' uji, sn.kunci voucher,
       CAST(sn.nilai AS NUMERIC(18,2)) gl_sebelum,
       CAST(g.gl AS NUMERIC(18,2)) gl_sesudah,
       CAST(g.gl - sn.nilai AS NUMERIC(18,2)) selisih,
       (CASE WHEN ABS(ISNULL(g.gl,0)-sn.nilai)<=0.01 THEN 'LULUS' ELSE 'GAGAL' END) status
FROM _snap_xper sn
LEFT JOIN (SELECT voucher, SUM(debet) gl FROM gl_journal
           WHERE modul_id='AS' AND account_id='102-020' GROUP BY voucher) g ON g.voucher=sn.kunci
WHERE sn.item='gl_102020';

-- 3c: HPP JUAL bln akhir = HPP WIP-Out bln awal  (harapan: sama persis)
SELECT 'B3 jual WIP = WIP-Out' uji, s2.evap, s1.bukti_id bukti_jual, CAST(s1.tgl AS DATE) tgl_jual,
       CAST(s2.hpp AS NUMERIC(18,2)) hpp_jual,
       CAST(sn.nilai AS NUMERIC(18,2)) hpp_wipout_awal,
       (CASE WHEN ABS(s2.hpp-sn.nilai)<=0.01 THEN 'LULUS' ELSE 'GAGAL' END) status
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
JOIN _snap_xper sn ON sn.item='wipout_hpp' AND sn.kunci=s2.evap
WHERE s1.tipe_trans IN ('22','32','26','36') AND s2.evap='CIM1096180';   -- <<< ganti :SER

-- ---------- Bersih-bersih ----------
-- DROP TABLE _snap_xper;
