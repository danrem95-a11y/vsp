-- (C) SALDO AWAL per kategori dari master FA_ASSET
SELECT category_code AS cat, COUNT(*) AS n_aset,
  CAST(SUM(acquisition_cost) AS numeric(20,2)) AS cost,
  CAST(SUM(accum_dep_beginning) AS numeric(20,2)) AS akum_awal,
  CAST(SUM(book_value_beginning) AS numeric(20,2)) AS nbv_awal
FROM FA_ASSET WHERE site_id='101'
GROUP BY category_code ORDER BY category_code;
