-- Breakdown per status
SELECT status, COUNT(*) n,
  CAST(SUM(acquisition_cost) AS numeric(20,2)) cost,
  CAST(SUM(accum_dep_beginning) AS numeric(20,2)) akum,
  CAST(SUM(book_value_beginning) AS numeric(20,2)) nbv
FROM FA_ASSET WHERE site_id='101' AND category_code='KDR' GROUP BY status;
