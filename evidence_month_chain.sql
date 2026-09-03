-- ============================================================
-- EVIDENCE #2 : MONTH CHAIN CONSISTENCY
--   opening(m+1) HARUS = opening(m) + GL_movement(m)   (per akun persediaan, 2026)
--   KOSONG (semua break <= Rp1000) = chain konsisten, tak ada phantom/loncat.
--   Sudah dijalankan di prod 2026-07-31: 11 baris putus (lihat FINAL_REFRESH_MODERN_ACCEPTANCE.md).
-- ============================================================
SELECT x.bln, x.acc,
       x.opening_m, x.opening_next, x.gl_mov,
       CAST(x.opening_next - (x.opening_m + x.gl_mov) AS numeric(20,2)) AS break_saldo
FROM (
  SELECT mm.bln, g.acc,
    CAST((SELECT isnull(sum(s.nilai),0) FROM sinv s
            JOIN im_produk pr ON pr.produk_id=s.stok_id
            JOIN im_product_group gr ON gr.kode_group=pr.group_product
          WHERE gr.persediaan=g.acc AND s.periode=mm.m) AS numeric(20,2)) AS opening_m,
    CAST((SELECT isnull(sum(s.nilai),0) FROM sinv s
            JOIN im_produk pr ON pr.produk_id=s.stok_id
            JOIN im_product_group gr ON gr.kode_group=pr.group_product
          WHERE gr.persediaan=g.acc AND s.periode=mm.mn) AS numeric(20,2)) AS opening_next,
    CAST((SELECT isnull(sum(debet-kredit),0) FROM gl_journal
          WHERE account_id=g.acc AND tgl >= mm.m AND tgl < mm.mn) AS numeric(20,2)) AS gl_mov
  FROM (            SELECT '01 Jan' bln, CAST('2026-01-01' AS date) m, CAST('2026-02-01' AS date) mn
       UNION ALL SELECT '02 Feb', CAST('2026-02-01' AS date), CAST('2026-03-01' AS date)
       UNION ALL SELECT '03 Mar', CAST('2026-03-01' AS date), CAST('2026-04-01' AS date)
       UNION ALL SELECT '04 Apr', CAST('2026-04-01' AS date), CAST('2026-05-01' AS date)
       UNION ALL SELECT '05 May', CAST('2026-05-01' AS date), CAST('2026-06-01' AS date)
       UNION ALL SELECT '06 Jun', CAST('2026-06-01' AS date), CAST('2026-07-01' AS date)
       UNION ALL SELECT '07 Jul', CAST('2026-07-01' AS date), CAST('2026-08-01' AS date)) mm
  CROSS JOIN (SELECT DISTINCT persediaan acc FROM im_product_group WHERE isnull(persediaan,'')<>'') g
) x
WHERE abs(x.opening_next - (x.opening_m + x.gl_mov)) > 1000
ORDER BY x.bln, abs(x.opening_next - (x.opening_m + x.gl_mov)) DESC;
