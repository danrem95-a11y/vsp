SELECT asset_code,
  CAST(acquisition_cost AS numeric(18,2)) cost,
  CAST(accum_dep_beginning AS numeric(18,2)) akum,
  CAST(book_value_beginning AS numeric(18,2)) nbv,
  status, CAST(acquisition_date AS date) acq, disposal_date disp
FROM FA_ASSET WHERE site_id='101' AND category_code='KDR'
ORDER BY acquisition_cost DESC;
