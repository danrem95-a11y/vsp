SELECT asset_code,
  CAST(acquisition_cost AS numeric(18,2)) cost,
  CAST(accum_dep_beginning AS numeric(18,2)) akum,
  CAST(book_value_beginning AS numeric(18,2)) nbv,
  CAST(acquisition_cost-(accum_dep_beginning+book_value_beginning) AS numeric(18,2)) sel,
  status, CAST(acquisition_date AS date) acq, asset_name
FROM FA_ASSET WHERE site_id='101' AND category_code='BGN'
ORDER BY acquisition_cost DESC;
