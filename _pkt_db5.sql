SELECT d.asset_code, month(d.period) bln, CAST(d.depreciation_amount AS numeric(14,2)) dep
FROM FA_DEPRECIATION d JOIN FA_ASSET a ON a.site_id=d.site_id AND a.asset_code=d.asset_code
WHERE a.site_id='101' AND a.category_code='PKT' AND a.acquisition_cost IN (7950000,785000)
  AND d.period BETWEEN '2026-01-01' AND '2026-03-31'
ORDER BY d.asset_code, bln;
