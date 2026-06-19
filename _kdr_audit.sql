-- Identitas: cost harus = akum_awal + nbv_awal. Cari yang melanggar (>Rp1)
SELECT asset_code, asset_name,
  CAST(acquisition_cost AS numeric(18,2)) cost,
  CAST(accum_dep_beginning AS numeric(18,2)) akum,
  CAST(book_value_beginning AS numeric(18,2)) nbv,
  CAST(acquisition_cost-(accum_dep_beginning+book_value_beginning) AS numeric(18,2)) selisih,
  status, acquisition_date
FROM FA_ASSET
WHERE site_id='101' AND category_code='KDR'
  AND ABS(acquisition_cost-(accum_dep_beginning+book_value_beginning))>1
ORDER BY ABS(acquisition_cost-(accum_dep_beginning+book_value_beginning)) DESC;
