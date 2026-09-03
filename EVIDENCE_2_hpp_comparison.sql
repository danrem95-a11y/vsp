-- =====================================================================
-- EVIDENCE #2  POST-REFRESH HPP COMPARISON   (ASA9)
-- Jalankan SETELAH refresh+close (Juni & Juli) dgn patch, di DB COPY.
-- Membandingkan tsales2.hpp LIVE (post) vs _pre_tsales2_hpp (baseline).
-- Kategori: SAFE_CHANGE vs REGRESSION.  Target: REGRESSION = 0.
-- =====================================================================
BEGIN
  IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='_cmp_hpp') THEN EXECUTE IMMEDIATE 'DROP TABLE _cmp_hpp'; END IF;
END;

-- ---- baris yg HPP-nya berubah (post <> pre), + cost fallback yg SEHARUSNYA ----
SELECT
  p.bukti_id, p.urut, p.stok_id, p.evap, p.tgl, p.tipe_trans,
  CAST(p.qty AS numeric(18,2))                    AS qty,
  p.hpp                                           AS hpp_pre,
  CAST(ISNULL(b.hpp,0) AS numeric(18,2))          AS hpp_post,
  CAST(ISNULL(b.hpp,0) - p.hpp AS numeric(18,2))  AS delta_hpp,
  CAST(ISNULL((SELECT MAX(c2.hpp) FROM tsales1 c1, tsales2 c2
        WHERE c1.bukti_id=c2.bukti_id AND c1.tipe_trans='88'
          AND c2.stok_id=p.stok_id AND c2.evap=p.evap AND ISNULL(c2.hpp,0)>0),0)
       AS numeric(18,2))                          AS fallback_cost
INTO _cmp_hpp
FROM _pre_tsales2_hpp p, tsales2 b
WHERE p.bukti_id=b.bukti_id AND p.urut=b.urut
  AND ISNULL(b.hpp,0) <> p.hpp;

-- ---- A. RINGKASAN kategori (yang diminta: kategori | jumlah | total_delta_hpp) ----
SELECT
  CASE WHEN evap <> '' AND fallback_cost > 0 AND hpp_post = fallback_cost
       THEN 'SAFE_CHANGE' ELSE 'REGRESSION' END AS kategori,
  COUNT(*) AS jumlah,
  CAST(SUM(delta_hpp) AS numeric(18,2)) AS total_delta_hpp
FROM _cmp_hpp
GROUP BY CASE WHEN evap <> '' AND fallback_cost > 0 AND hpp_post = fallback_cost
              THEN 'SAFE_CHANGE' ELSE 'REGRESSION' END
ORDER BY 1;

-- ---- B. DAFTAR baris REGRESSION (harus KOSONG) — bukti untuk auditor ----
SELECT bukti_id, urut, stok_id, evap, tipe_trans, qty, hpp_pre, hpp_post, fallback_cost
FROM _cmp_hpp
WHERE NOT (evap <> '' AND fallback_cost > 0 AND hpp_post = fallback_cost)
ORDER BY stok_id, bukti_id;

-- ---- C. DAFTAR baris SAFE_CHANGE (transaksi yg dikoreksi) ----
SELECT bukti_id, urut, stok_id, evap, tipe_trans, tgl, qty,
       hpp_pre, hpp_post, delta_hpp,
       CAST(qty*delta_hpp AS numeric(18,2)) AS delta_cogs
FROM _cmp_hpp
WHERE evap <> '' AND fallback_cost > 0 AND hpp_post = fallback_cost
ORDER BY tgl, stok_id;
