SELECT COUNT(*) n, CAST(SUM(acquisition_cost) AS numeric(20,2)) cost FROM FA_ASSET WHERE site_id='101' AND category_code='PKT';
