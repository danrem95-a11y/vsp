SELECT asset_code, asset_name, CAST(acquisition_cost AS numeric(18,2)) cost,
  CAST(accum_dep_beginning AS numeric(18,2)) akum, status, CAST(acquisition_date AS date) acq
FROM FA_ASSET WHERE site_id='101' AND category_code='KDR'
  AND acquisition_date BETWEEN '2022-10-01' AND '2022-12-31'
ORDER BY acquisition_date;
