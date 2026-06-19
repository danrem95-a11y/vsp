SELECT asset_code, asset_name, CAST(acquisition_cost AS numeric(18,2)) cost,
  CAST(accum_dep_beginning AS numeric(18,2)) akum, CAST(book_value_beginning AS numeric(18,2)) nbv,
  CAST(acquisition_date AS date) acq, beginning_period, status
FROM FA_ASSET WHERE site_id='101' AND category_code='PKT'
  AND (acquisition_cost IN (7950000,785000) OR acquisition_date>='2025-12-01')
ORDER BY acquisition_date DESC;
