-- (A) SUB-LEDGER: penyusutan per kategori per bulan (Jan-Jun 2026)
SELECT a.category_code AS cat, month(d.period) AS bln,
       CAST(SUM(d.depreciation_amount) AS numeric(20,2)) AS depr
FROM FA_DEPRECIATION d JOIN FA_ASSET a ON a.site_id=d.site_id AND a.asset_code=d.asset_code
WHERE d.site_id='101' AND d.period BETWEEN '2026-01-01' AND '2026-06-30'
GROUP BY a.category_code, month(d.period) ORDER BY a.category_code, bln;
