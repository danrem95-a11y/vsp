-- 5 aset yang dikurangkan di rekonsiliasi WP (per cost) untuk turun ke GL book
SELECT asset_code, asset_name, CAST(acquisition_cost AS numeric(18,2)) cost,
  CAST(accum_dep_beginning AS numeric(18,2)) akum, CAST(book_value_beginning AS numeric(18,2)) nbv,
  status, CAST(acquisition_date AS date) acq
FROM FA_ASSET WHERE site_id='101' AND category_code='KDR'
  AND acquisition_cost IN (175911139,178638000,193897458,176885845,240000000)
ORDER BY acquisition_cost DESC;
