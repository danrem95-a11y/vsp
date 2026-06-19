SELECT category_code, MAX(asset_code) maxcode, COUNT(*) n FROM FA_ASSET WHERE site_id='101' AND category_code IN ('BGN','TNH') GROUP BY category_code;
