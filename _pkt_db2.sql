SELECT asset_code, asset_name, CAST(acquisition_cost AS numeric(18,2)) cost, status, CAST(acquisition_date AS date) acq
FROM FA_ASSET WHERE site_id='101' AND category_code='PKT' AND acquisition_cost=8735000;
