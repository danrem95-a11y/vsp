-- Apakah aset yg akan "dikeluarkan" punya penyusutan 2026 yang SUDAH terposting?
SELECT a.asset_code, a.asset_name, a.status,
  CAST(a.acquisition_cost AS numeric(18,2)) cost,
  COUNT(d.period) bln_2026,
  CAST(SUM(d.depreciation_amount) AS numeric(18,2)) depr_2026
FROM FA_ASSET a
LEFT JOIN FA_DEPRECIATION d ON d.site_id=a.site_id AND d.asset_code=a.asset_code
  AND d.period BETWEEN '2026-01-01' AND '2026-06-30'
WHERE a.site_id='101' AND a.category_code='KDR'
  AND a.asset_code IN ('KDR-0016','KDR-0017','KDR-0018','KDR-0019',
                       'KDR-0002','KDR-0003','KDR-0004','KDR-0031')
GROUP BY a.asset_code, a.asset_name, a.status, a.acquisition_cost
ORDER BY depr_2026 DESC;
