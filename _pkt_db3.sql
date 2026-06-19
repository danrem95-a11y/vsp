SELECT asset_code, asset_name, CAST(acquisition_cost AS numeric(18,2)) cost,
  CAST(accum_dep_beginning AS numeric(18,2)) akum, CAST(book_value_beginning AS numeric(18,2)) nbv,
  CAST(acquisition_date AS date) acq, beginning_period, remaining_life_begin rl, status
FROM FA_ASSET WHERE site_id='101' AND category_code='PKT' AND acquisition_cost BETWEEN 8600000 AND 8800000;
