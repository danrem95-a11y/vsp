SELECT category_code, count(*) n FROM FA_ASSET WHERE site_id='101' GROUP BY category_code ORDER BY category_code;
